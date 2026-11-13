# Talos: SSD-Nutzung und Wechsel der Control Plane

Stand: 2026-11-13. Planungsdokument; die hier beschriebene Migration wurde
noch nicht durchgeführt. Destruktive Befehle werden erst nach Validierung
des konkreten Talos-1.14.6-Ablaufs für den jeweiligen Node festgelegt.

## Ausgangslage

Vier CM4-Module laufen auf einem Turing Pi 2 mit Talos 1.14.6. Auf allen
Nodes liegen Bootsystem und das rund 29 GB große `EPHEMERAL`-Volume (`/var`)
auf der eMMC. Damit nutzen auch Container-Images, beschreibbare
Container-Schichten, Logs und lokale Kubelet-Daten bisher die eMMC.

Die Zusatzlaufwerke sind weiterhin unter `/var/lib/longhorn` eingebunden.
Longhorn ist laut Betreiber außer Betrieb; seine alten Daten werden nicht
mehr benötigt und dürfen im Rahmen der Migration entfernt werden.
Die aktuellen App-PVCs verwenden Synology-iSCSI und bleiben erhalten.

Die aktuelle Control Plane `talos-test03` ist bereits mit
`node-role.kubernetes.io/control-plane:NoSchedule` getaintet. Das ist auch im
Repository vorgesehen: `talos/patches/controller/cluster.yaml` setzt
`cluster.allowSchedulingOnControlPlanes: false`; die generierte Konfiguration
für Node 3 enthält diesen Wert ebenfalls. Bei der Live-Prüfung liefen dort
ausschließlich System- und Infrastruktur-Pods. Der Rollenwechsel soll diese
bestehende Trennung auf Node 4 übernehmen.

| Node | Aktuelle Rolle | Erkanntes Zusatzlaufwerk | Belegung des Longhorn-Dateisystems beim Prüfen |
| --- | --- | --- | --- |
| talos-test01 | Worker | 1 TB SATA-SSD | ca. 89 GB belegt, 934 GB frei |
| talos-test02 | Worker | 1 TB SATA-SSD | ca. 65 GB belegt, 959 GB frei |
| talos-test03 | einzige Control Plane | 1 TB SATA-SSD | Dateisystem nur ca. 10,7 GB groß, ca. 0,8 GB belegt |
| talos-test04 | Worker | 2 TB USB-HDD, WD Elements | ca. 45 GB belegt, 1.955 GB frei |

Die Werte sind eine Momentaufnahme. Bei Node 3 ist die Disk beziehungsweise
Partition rund 1 TB groß, das gemountete XFS-Dateisystem jedoch wesentlich
kleiner. Bei einer Neuanlage muss die nutzbare Größe ausdrücklich geprüft werden.

### Hardware-Grenzen

Nach Angaben des Betreibers hat ein Modul SATA direkt; zwei weitere erhalten
SATA über PCIe-Erweiterungen. Beim vierten Modul besteht nach aktuellem
Kenntnisstand keine weitere SATA-/PCIe-Erweiterungsmöglichkeit.
Die genaue Zuordnung der Anschlusswege ist vor Eingriffen am Board zu prüfen.
Der Plan setzt für Node 4 keinen zusätzlichen SATA-Anschluss voraus.

## Bevorzugtes Zielbild

| Node | Zielrolle | Lokaler Speicher |
| --- | --- | --- |
| talos-test01 | Worker | Bootsystem auf eMMC, `/var` auf SATA-SSD |
| talos-test02 | Worker | Bootsystem auf eMMC, `/var` auf SATA-SSD |
| talos-test03 | Worker nach Control-Plane-Wechsel | Bootsystem auf eMMC, `/var` auf SATA-SSD |
| talos-test04 | dedizierte Control Plane | zunächst eMMC für Bootsystem, etcd und Laufzeitdaten |

Die App-PVCs bleiben auf Synology-iSCSI. Lokale SSDs dienen der
Container-Laufzeit; Longhorn wird nicht wieder installiert.

Eine dedizierte Control Plane auf Node 4 benötigt voraussichtlich weniger
Image- und App-Speicher als ein Worker. Das setzt voraus, dass dort keine
normalen App-Workloads laufen: die bestehende Einstellung
`allowSchedulingOnControlPlanes: false` beibehalten, den daraus resultierenden
Control-Plane-Taint nach dem Rollenwechsel prüfen und vorhandene Tolerations
sowie Affinitäten kontrollieren.
Weniger RAM- oder CPU-Bedarf ist damit nicht zugesichert; API-Server und etcd
können weiterhin erhebliche Ressourcen benötigen.

etcd reagiert empfindlich auf Schreib-Latenz und benötigt zuverlässigen
Speicher. Vor dem Rollenwechsel eMMC-Zustand, freien Platz und etcd-/I/O-Latenzen
bewerten. Die USB-HDD ist kein automatisch besserer etcd-Speicher.
Falls eMMC ungeeignet ist, kommt eine USB-SSD infrage; Stromversorgung,
USB-Anbindung, Adapter und Talos-Erkennung müssen vorher geprüft werden.

Auch nach dem Wechsel gibt es nur eine Control Plane und damit keine
Control-Plane-Hochverfügbarkeit. Während ihrer Wartung ist die Kubernetes-API
nicht verfügbar; bereits laufende Workloads können weiterlaufen.

## Umsetzung in Etappen

### 1. Bestehende Reparatur abschließen und Ausgangslage sichern

- Den getesteten Kyverno-Fix dauerhaft in Git übernehmen und durch Flux
  abgleichen lassen. Der Live-Fix allein ist keine dauerhafte Lösung.
- OpenBao-Zugriff und frische External-Secrets-Synchronisation prüfen.
- CSI- und Container-Runtime-Probleme eingrenzen; die SSD-Migration ist keine
  nachgewiesene Lösung für sämtliche beobachteten Timeouts.
- Den Descheduler während der Migration pausiert lassen und seinen vorherigen
  Sollzustand festhalten. Unnötige Pod-Verschiebungen vermeiden.
- App-Backups und Wiederherstellbarkeit prüfen, besonders Litestream-Datenbanken.
  Vorhandene PVCs nicht löschen; einige StorageClasses haben ReclaimPolicy `Delete`.
- Aktuelle MachineConfigs, Cluster-Secrets, Talosconfig und Kubeconfig sicher
  außerhalb der umzubauenden Nodes sichern. Keine Klartext-Zugangsdaten committen.
- Einen aktuellen etcd-Snapshot extern sichern und das Wiederherstellungsverfahren
  vor dem Control-Plane-Wechsel festlegen.

### 2. Konfiguration im Repository vorbereiten

- In `talos/talconfig.yaml` die zukünftigen Rollen und nodeabhängigen
  Storage-Konfigurationen vorbereiten. Rollenwechsel und SSD-Umstellung getrennt
  ausrollbar halten.
- Den alten Patch `talos/patches/global/machine-longhorn.yaml` einschließlich
  Longhorn-Mount und Kubelet-Bind-Mount ablösen. Nicht gleichzeitig ungeprüft auf
  alle laufenden Nodes anwenden.
- Für SSD-Worker `/var` über ein Talos-`VolumeConfig` für `EPHEMERAL` auf dem
  vorgesehenen lokalen Laufwerk planen. Bestehendes Volume und neue Provisionierung
  müssen anhand des genauen Talos-Verhaltens getrennt behandelt werden.
- Selektoren je Node prüfen. `/dev/sda` allein ist keine hinreichende
  Löschfreigabe; lokale SATA-/USB-Disks von eingebundenen iSCSI-LUNs unterscheiden.
- Parallele Image-Pulls auf einen kleinen, getesteten Wert begrenzen. Aktuell
  ist im Zuge der Stabilisierung `maxParallelImagePulls: 2` bei
  `serializeImagePulls: false` vorgesehen; den wirksamen Wert vor der Migration
  auf allen Nodes prüfen.
- Mit den bestehenden Cluster-Secrets `task talos:generate-config` ausführen,
  die generierten Konfigurationen validieren und den Diff prüfen.

Talos 1.14 unterstützt dedizierte System-Volumes. Für `CRI`, `KUBELET`, `LOG`
und `ETCD` ist der Wechsel zwischen bestehendem Verzeichnis und eigener Partition
jedoch keine unterstützte Live-Migration. Ein einfacher Config-Patch verschiebt
auch ein vorhandenes `EPHEMERAL`-Dateisystem nicht automatisch auf eine andere Disk.
Der konkrete Reset-/Neuprovisionierungsablauf muss vor dem ersten Löschen geprüft
werden; dieses Dokument ist dafür noch keine ausführbare Befehlsfolge.

### 3. Pilot auf talos-test01

1. Prüfen, dass die übrigen Nodes die zu verschiebenden Workloads aufnehmen können.
2. Node cordonen und kontrolliert drainen; PDBs und lokale Daten berücksichtigen.
3. Vollständiges Unmount und Detach seiner iSCSI-Volumes abwarten.
4. Den alten Longhorn-Mount gemäß validiertem Talos-Ablauf außer Betrieb nehmen.
5. Ausschließlich die eindeutig identifizierte ehemalige Longhorn-SSD bereinigen.
6. Den Worker mit der vorbereiteten Storage-Konfiguration neu provisionieren.
   Bestehende Cluster-Secrets verwenden; kein neues Cluster bootstrappen.
7. Prüfen, dass `/var` auf der SSD liegt und die gewünschte Kapazität nutzbar ist.
8. CSI, DNS, Netzwerk, Image-Pulls und einen App-Start mit bestehendem iSCSI-PVC testen.
9. Erst nach erfolgreicher Prüfung uncordonen und eine Beobachtungsphase einhalten.

Vor dem nächsten Node müssen Pod-Starts zuverlässig funktionieren und neue
CRI-/Mount-Timeouts sowie DiskPressure ausgeschlossen beziehungsweise erklärt sein.

### 4. talos-test02 umstellen

Den erprobten Worker-Ablauf wiederholen. Wegen der dort beobachteten CRI-Timeouts
vorher prüfen, ob Drain und sauberes Trennen der Volumes möglich sind.
Keine erzwungene parallele Bereinigung auf mehreren Nodes durchführen.

### 5. Control Plane von talos-test03 auf talos-test04 wechseln

1. Wartungsfenster, externen etcd-Snapshot und Wiederherstellungszugang bestätigen.
2. Die Apps von Node 4 auf die bereits geprüften SSD-Worker verschieben;
   iSCSI-Volumes sauber trennen. Node 3 bleibt dabei unverändert verfügbar.
3. Den unterstützten Talos-Ablauf zum Neuaufsetzen beziehungsweise Rollenwechsel
   des bisherigen Workers mit bestehender Cluster-Identität validieren.
4. Node 4 als zusätzliche Control Plane in den bestehenden Cluster aufnehmen.
   Keinen neuen Cluster bootstrappen.
5. etcd-Mitgliedschaft, Datenreplikation, API-Zugriff, Zertifikate und die
   VIP `192.168.13.10` prüfen. Der bisherige direkte Talos-Endpunkt ist
   `192.168.13.13`; ihn vor Entfernung von Node 3 passend umstellen.
6. Node 4 erst als übernommen betrachten, wenn seine Control-Plane-Dienste und
   sein Speicher stabil sind. Die Entfernung des alten etcd-Mitglieds im
   unterstützten Verfahren durchführen, solange die erforderlichen Mitglieder
   erreichbar sind.
7. Anschließend Node 3 kontrolliert als Worker mit SSD-Layout neu provisionieren.

Ein Zwischenzustand mit zwei etcd-Mitgliedern benötigt beide für Quorum und
liefert keine Ausfalltoleranz. Alten Node nicht einfach abschalten oder löschen.
Vor Durchführung entscheiden, ob für den Übergang ein drittes temporäres
Control-Plane-Mitglied benötigt wird. Das neue Layout auf Node 3 erst anfassen,
wenn die Übernahme und Entfernung aus der Control Plane abgeschlossen sind.

### 6. Abschluss

- Alle Node-Rollen, Taints, Talos-Endpunkte und Disk-Mounts dokumentieren.
- HelmReleases, Flux-Kustomizations, CSI und ExternalSecrets auf Gesundheit prüfen.
- Bei Node 4 nur die notwendigen System-Pods zulassen und eMMC-Belegung,
  etcd-Latenzen sowie Schreiblast beobachten.
- Die 2-TB-USB-HDD ist für das Zielbild nicht erforderlich. Alte Longhorn-Daten
  können später entfernt werden; eine weitere Nutzung wird separat festgelegt.
- Descheduler erst nach Prüfung seiner Regeln und stabiler Workload-Verteilung
  wieder aktivieren. Den pausierten Policy-Abgleich nach Git-Übernahme fortsetzen.
- Eine neue externe etcd-Sicherung und die endgültigen Konfigurationen sichern.

## Rückweg

Bis zur Entfernung der alten Control Plane bleibt Node 3 der Rückfallpunkt.
Nach erfolgreicher Entfernung hängt eine Wiederherstellung von Node 4 oder
vom externen etcd-Snapshot ab; Node 3 lässt sich dann nicht einfach unverändert
als frühere Control Plane einschalten.

Ein zurückzubauender Worker kann mit der gesicherten eMMC-Konfiguration und den
bestehenden Cluster-Secrets neu provisioniert werden. Lokale Images werden neu
geladen. iSCSI-PVCs bleiben erhalten; Apps mit lokalen Daten benötigen ihr Backup.
Die als entbehrlich freigegebenen Longhorn-Daten werden nicht wiederhergestellt.

## Referenzen

- [Talos 1.14: Release Notes und dedizierte System-Volumes](https://github.com/siderolabs/talos/discussions/14230)
- [Talos VolumeConfig: Validierung bestehender System-Volumes](https://pkg.go.dev/github.com/siderolabs/talos/pkg/machinery/config/types/block#VolumeConfigV1Alpha1.RuntimeValidate)
- [Cluster-Konfiguration](../talos/talconfig.yaml)
- [Backups](backups.md) und [Disaster Recovery](dr.md)
- [Kyverno-Migration und Live-Fix](kyverno-cel-migration.md)
