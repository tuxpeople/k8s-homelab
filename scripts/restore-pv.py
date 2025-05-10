import os
import shutil
import yaml
from kubernetes import client, config
import argparse

parser = argparse.ArgumentParser(description="Generate Longhorn Volume Restore Manifests")
parser.add_argument('--namespace', default='longhorn-system', help='Namespace of Longhorn (default: longhorn-system)')
args = parser.parse_args()

# Konfiguration laden (lokal oder im Cluster)
config.load_kube_config()

v1 = client.CustomObjectsApi()
core_v1 = client.CoreV1Api()

BACKUP_NAMESPACE = args.namespace
VOLUME_GROUP = "longhorn.io"
VOLUME_VERSION = "v1beta1"
VOLUME_PLURAL = "volumes"
SETTING_PLURAL = "settings"
SETTING_REPLICA_COUNT = "default-replica-count"
BACKUP_PLURAL = "backups"

OUTPUT_DIR = "/tmp/longhorn/restore"
OUTPUT_DIR_VOLUME = os.path.join(OUTPUT_DIR, "volumes")
OUTPUT_DIR_PVC = os.path.join(OUTPUT_DIR, "pvcs")
os.makedirs(OUTPUT_DIR, exist_ok=True)
os.makedirs(OUTPUT_DIR_VOLUME, exist_ok=True)
os.makedirs(OUTPUT_DIR_PVC, exist_ok=True)

def cleanup_files():
    for folder in OUTPUT_DIR_VOLUME, OUTPUT_DIR_PVC:
      for filename in os.listdir(folder):
        file_path = os.path.join(folder, filename)
        try:
            if os.path.isfile(file_path) or os.path.islink(file_path):
                os.unlink(file_path)
            elif os.path.isdir(file_path):
                shutil.rmtree(file_path)
            print('Deleted %s.' % (file_path))
        except Exception as e:
            print('Failed to delete %s. Reason: %s' % (file_path, e))

def generate_kustomization(directories):
    for directory in directories:
        # Alle YAML-Dateien im Verzeichnis sammeln
        yaml_files = sorted([
            f for f in os.listdir(directory)
            if f.endswith(".yaml") or f.endswith(".yml")
        ])

        if not yaml_files:
            print(f"⚠️  Keine YAML-Dateien in {directory} gefunden – überspringe")
            continue

        resources = [f"./{f}" for f in yaml_files]

        kustomization = {
            "apiVersion": "kustomize.config.k8s.io/v1beta1",
            "kind": "Kustomization",
            "resources": resources
        }

        output_path = os.path.join(directory, "kustomization.yaml")
        with open(output_path, "w") as f:
            yaml.dump(kustomization, f, sort_keys=False)

        print(f"✅ kustomization.yaml erstellt in: {output_path}")

def get_existing_volumes():
    volumes = v1.list_cluster_custom_object(
        group=VOLUME_GROUP,
        version=VOLUME_VERSION,
        plural=VOLUME_PLURAL
    )
    return {v["metadata"]["name"] for v in volumes["items"]}

def get_all_backups():
    backups = v1.list_namespaced_custom_object(
        group=VOLUME_GROUP,
        version=VOLUME_VERSION,
        plural=BACKUP_PLURAL,
        namespace=BACKUP_NAMESPACE
    )
    return backups["items"]

def get_default_replica_count():
    try:
        setting = v1.get_namespaced_custom_object(
            group=VOLUME_GROUP,
            version=VOLUME_VERSION,
            plural=SETTING_PLURAL,
            namespace=BACKUP_NAMESPACE,
            name=SETTING_REPLICA_COUNT
        )

        # Extrahiere den Wert aus der Antwort
        replica_count = int(setting['value'])
        return replica_count
    except client.exceptions.ApiException as e:
        print(f"Fehler beim Abrufen von default-replica-count: {e}")
        return 3  # Fallback-Wert 3, falls der API-Aufruf fehlschlägt

def write_yaml(obj, filename):
    with open(filename, "w") as f:
        yaml.dump(obj, f, sort_keys=False)

def sanitize_filename(name):
    return name.replace("/", "-")

def bytes_to_human_readable(size_bytes):
    units = ['Gi', 'Ti', 'Pi']
    size = float(size_bytes)
    for unit in units:
        if size < 1024 * 1024 * 1024 * 1024:
            return f"{int(size / (1024 ** 3))}{unit}"
        size /= 1024
    return f"{int(size)}Pi"

def generate_manifests():
    existing_volumes = get_existing_volumes()
    backups = get_all_backups()

    for backup in backups:
        backup_name = backup["metadata"]["name"]
        volume_name = (
          backup.get("metadata", {}).get("labels", {}).get("longhornvolume")
          or backup.get("metadata", {}).get("labels", {}).get("backup-volume")
        )

        if not volume_name or volume_name in existing_volumes:
            print(f"✅ Volume '{volume_name}' existiert oder unbrauchbar – überspringe")
            continue

        backup_url = backup["status"].get("url")
        size_bytes = backup["status"].get("size")
        number_of_replicas = get_default_replica_count()

        if not backup_url or not size_bytes:
            print(f"⚠️ Kein Backup-URL oder -Größe für {backup_name}")
            continue

        size_human = bytes_to_human_readable(int(size_bytes))

        print(f"🛠️ Erzeuge Restore-YAML für Volume: {volume_name} ({size_human})")

        # Volume manifest
        volume_manifest = {
            "apiVersion": "longhorn.io/v1beta1",
            "kind": "Volume",
            "metadata": {"name": volume_name},
            "spec": {
                "numberOfReplicas": number_of_replicas,
                "fromBackup": backup_url,
            }
        }

        # PVC manifest
        pvc_manifest = {
            "apiVersion": "v1",
            "kind": "PersistentVolumeClaim",
            "metadata": {"name": volume_name},
            "spec": {
                "accessModes": ["ReadWriteOnce"],
                "resources": {"requests": {"storage": size_human}},
                "storageClassName": "longhorn",
                "volumeName": volume_name
            }
        }

        base_volume = os.path.join(OUTPUT_DIR_VOLUME, sanitize_filename(volume_name))
        write_yaml(volume_manifest, f"{base_volume}-volume.yaml")

        base_pvc = os.path.join(OUTPUT_DIR_PVC, sanitize_filename(volume_name))
        write_yaml(pvc_manifest, f"{base_pvc}-pvc.yaml")

if __name__ == "__main__":
    cleanup_files()
    generate_manifests()
    generate_kustomization([
        OUTPUT_DIR_PVC,
        OUTPUT_DIR_VOLUME
    ])
