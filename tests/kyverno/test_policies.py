"""Behavioural regression tests for the CEL migration; requires kyverno and yq."""
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
POLICIES = ROOT / 'kubernetes/apps/security/kyverno/policies'


def resource(kind='Pod', spec=None, namespace='default', **metadata):
    group = {'Ingress': 'networking.k8s.io/v1', 'Deployment': 'apps/v1',
             'StatefulSet': 'apps/v1', 'HelmRelease': 'helm.toolkit.fluxcd.io/v2'}
    obj = {'apiVersion': group.get(kind, 'v1'), 'kind': kind,
           'metadata': {'name': 'example', 'namespace': namespace, **metadata}}
    obj['spec'] = spec if spec is not None else {'containers': [{'name': 'app', 'image': 'nginx:1.27'}]}
    return obj


class Policies(unittest.TestCase):
    def evaluate(self, policy, obj, expected='pass', labels=None):
        with tempfile.TemporaryDirectory() as tmp:
            src, out = Path(tmp) / 'resource.json', Path(tmp) / 'result.yaml'
            src.write_text(json.dumps(obj))
            extra = []
            if labels is not None:
                values = Path(tmp) / 'values.json'
                values.write_text(json.dumps({'apiVersion': 'cli.kyverno.io/v1alpha1', 'kind': 'Values',
                    'namespaceSelector': [{'name': obj['metadata'].get('namespace', 'default'), 'labels': labels}]}))
                extra = ['-f', str(values)]
            result = subprocess.run(['kyverno', 'apply', str(POLICIES / (policy + '.yaml')),
                                     '-r', str(src), '--output-file', str(out)] + extra,
                                    capture_output=True, text=True, check=False)
            self.assertIn('error: 0', result.stdout, result.stdout + result.stderr)
            if expected == 'skip':
                self.assertRegex(result.stdout, r'pass: 0, fail: 0, warn: 0, error: 0, skip: [01]')
            else:
                self.assertIn(expected + ': 1', result.stdout, result.stdout + result.stderr)
            if not out.exists() or not out.read_text().strip():
                return None
            data = subprocess.check_output(['yq', 'eval-all', '-o=json',
                                            '. as $item ireduce ([]; . + [$item])', str(out)])
            return [d for d in json.loads(data) if d is not None][-1]

    def test_cpu_limits(self):
        pod = resource(spec={'containers': [{'name': 'app', 'image': 'nginx:1.27',
                         'resources': {'limits': {'cpu': '100m', 'memory': '64Mi'}}}],
                         'initContainers': [{'name': 'init', 'image': 'busybox:1.36'}]})
        out = self.evaluate('limits', pod)
        self.assertEqual(out['spec']['containers'][0]['resources']['limits'], {'memory': '64Mi'})
        pod['metadata']['namespace'] = 'security'
        self.evaluate('limits', pod, 'skip')
        self.evaluate('limits', resource())  # missing limits must not cause a remove error

    def test_seccomp(self):
        self.assertEqual(self.evaluate('seccomp-default', resource())['spec']['securityContext'],
                         {'seccompProfile': {'type': 'RuntimeDefault'}})
        pod = resource(spec={'containers': [{'name': 'app', 'image': 'nginx:1.27'}],
                             'securityContext': {'seccompProfile': {'type': 'Unconfined'}}})
        self.evaluate('seccomp-default', pod, 'skip')
        self.evaluate('seccomp-default', resource(namespace='kube-system'), 'skip')

    def test_annotations(self):
        for kind in ['Deployment', 'StatefulSet', 'DaemonSet']:
            obj = resource(kind=kind)
            if kind == 'DaemonSet':
                obj['apiVersion'] = 'apps/v1'
            out = self.evaluate('reloader', obj)
            self.assertEqual(out['metadata']['annotations']['reloader.stakater.com/auto'], 'true')
        obj = resource(kind='Deployment', annotations={'reloader.stakater.com/auto': 'false'})
        self.assertEqual(self.evaluate('reloader', obj)['metadata']['annotations'], obj['metadata']['annotations'])
        for cls, target in [('internal', '192.168.13.64'), ('external', 'external.${SECRET_DOMAIN}')]:
            obj = resource('Ingress', {'ingressClassName': cls})
            out = self.evaluate('ingress', obj)
            self.assertEqual(out['metadata']['annotations']['external-dns.kubernetes.io/target'], target)
            obj['metadata']['annotations'] = {'external-dns.kubernetes.io/target': 'custom'}
            self.assertEqual(self.evaluate('ingress', obj)['metadata']['annotations'], obj['metadata']['annotations'])

    def test_helm_defaults(self):
        for spec in [{}, {'upgrade': {}}, {'upgrade': {'remediation': {}}}]:
            out = self.evaluate('helmrelease-defaults', resource('HelmRelease', spec))
            self.assertEqual(out['spec']['upgrade']['remediation']['strategy'], 'uninstall')
        self.evaluate('helmrelease-defaults', resource('HelmRelease',
                      {'upgrade': {'remediation': {'strategy': 'rollback'}}}), 'skip')

    def test_validation(self):
        self.evaluate('restrict-deprecated-registry', resource())
        pod = resource()
        pod['spec']['ephemeralContainers'] = [{'name': 'debug', 'image': 'k8s.gcr.io/pause:3.9'}]
        self.evaluate('restrict-deprecated-registry', pod, 'fail')
        for image in ['nginx', 'nginx:latest']:
            pod = resource()
            pod['spec']['containers'][0]['image'] = image
            self.evaluate('restrict-latest-tag', pod, 'fail')
        self.evaluate('restrict-latest-tag', resource())
        pod = resource()
        pod['spec']['containers'][0]['securityContext'] = {'privileged': True}
        self.evaluate('restrict-privileged', pod, 'fail')
        pod['metadata']['namespace'] = 'storage'
        self.evaluate('restrict-privileged', pod, 'skip')
        self.evaluate('restrict-privileged', resource(spec={'containers': [], 'hostPID': True}), 'fail')
        for kind, spec in [('PersistentVolumeClaim', {}), ('StatefulSet', {'volumeClaimTemplates': [{'spec': {}}]})]:
            self.evaluate('require-storageclass', resource(kind, spec), 'fail')
        self.evaluate('require-storageclass', resource('StatefulSet', {}))
        self.evaluate('require-storageclass', resource('PersistentVolumeClaim', {'storageClassName': 'synology-iscsi'}))

    def test_generators(self):
        for cls, dns in [('external', '1.1.1.1'), ('internal', '192.168.13.1')]:
            obj = resource('Ingress', {'ingressClassName': cls, 'rules': [{'host': 'example.test',
                           'http': {'paths': [{'path': '/health'}]}}]})
            out = self.evaluate('gatus-' + cls, obj)
            self.assertEqual(out['metadata']['name'], 'example-gatus-ep')
            self.assertIn('https://example.test/health', out['data']['config.yaml'])
            self.assertIn('tcp://' + dns + ':53', out['data']['config.yaml'])
            obj['metadata']['annotations'] = {'gatus.io/name': 'Custom', 'gatus.io/path': '/ready',
                'gatus.io/host': 'override.test', 'gatus.io/status-code': '204'}
            out = self.evaluate('gatus-' + cls, obj)
            self.assertIn('https://override.test/ready', out['data']['config.yaml'])
            self.assertIn('[STATUS] == 204', out['data']['config.yaml'])
            obj['metadata']['annotations']['gatus.io/enabled'] = 'false'
            self.evaluate('gatus-' + cls, obj, 'skip')
        secret = {'apiVersion': 'v1', 'kind': 'Secret', 'metadata': {
            'name': 'example-production-tls', 'namespace': 'cert-manager'},
            'type': 'kubernetes.io/tls', 'data': {'tls.crt': 'ZmFrZQ==', 'tls.key': 'ZmFrZQ=='}}
        out = self.evaluate('sync-production-tls', secret)
        self.assertEqual(out['data'], secret['data'])
        self.assertEqual(out['metadata']['namespace'], 'network')
        secret['metadata']['namespace'] = 'default'
        self.evaluate('sync-production-tls', secret, 'skip')

    def test_namespace_exclusions(self):
        for policy in ['limits', 'seccomp-default', 'restrict-latest-tag',
                       'restrict-privileged', 'restrict-deprecated-registry']:
            self.evaluate(policy, resource(), 'skip', labels={'kyverno.io/exclude': 'true'})

    def test_ndots(self):
        pod = resource()
        self.evaluate('ndots', pod, 'skip')
        labels = {'kyverno.io/ndots': 'true'}
        self.assertEqual(self.evaluate('ndots', pod, labels=labels)['spec']['dnsConfig']['options'],
                         [{'name': 'ndots', 'value': '1'}])
        pod['spec']['dnsConfig'] = {'options': [{'name': 'ndots', 'value': '5'}, {'name': 'timeout', 'value': '2'}]}
        out = self.evaluate('ndots', pod, labels=labels)
        self.assertEqual(out['spec']['dnsConfig']['options'],
                         [{'name': 'timeout', 'value': '2'}, {'name': 'ndots', 'value': '1'}])
        pod['metadata']['annotations'] = {'kyverno.io/exclude': 'true'}
        self.evaluate('ndots', pod, 'skip', labels=labels)

    def test_namespace_labels(self):
        ns = {'apiVersion': 'v1', 'kind': 'Namespace', 'metadata': {'name': 'example'}}
        out = self.evaluate('label-existing-namespaces', ns)
        self.assertEqual(out['metadata']['labels']['goldilocks.fairwinds.com/enabled'], 'true')

    def test_pullsecret(self):
        pod = resource()
        pod['spec']['containers'][0]['image'] = 'ghcr.io/example/app:v1'
        self.assertEqual(self.evaluate('ghcr-pullsecret', pod)['spec']['imagePullSecrets'],
                         [{'name': 'ghcr-pullsecret'}])
        pod['spec']['imagePullSecrets'] = [{'name': 'existing'}]
        self.evaluate('ghcr-pullsecret', pod, 'skip')


if __name__ == '__main__':
    unittest.main()
