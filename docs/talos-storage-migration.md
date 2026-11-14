# Talos: SSD-Nutzung und Wechsel der Control Plane

Stand: 2026-11-14. `talos-test01` und `talos-test02` verwenden `/var` erfolgreich
auf SATA-SSD. Nodes 3 und 4 sowie der Control-Plane-Wechsel bleiben nachgelagerte Etappen.
Der aktuelle Ausführungsstand steht im Abschnitt „Pilot-Ausführung“.

Nach erfolgreichem Pilot wird `talos-test02` mit demselben Ziel-Layout vorbereitet.
Seine SSD ist über `/dev/disk/by-id/ata-P3-1TB_0009478001526` eindeutig identifiziert.
Die alte Longhorn-Partition wird erst nach dem Neustart und nachgewiesenem
Aushängen gezielt gelöscht. Die Legacy-Disk-Konfiguration nicht vor dem Reset
live entfernen: Auf Node 2 führte dies zu einem gegenseitigen Finalizer-Wartezustand
der Talos-Volume-Controller. Ein erzwungener Neustart des bereits geleerten und
gestoppten Workers löst diesen Zustand; anschließend Layout erneut prüfen und
den selektiven EPHEMERAL-Reset bei Bedarf wiederholen.

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
4. Die minimale SSD-Zielkonfiguration ohne Legacy-Longhorn-Felder staged hinterlegen.
   Laufende Legacy-Mounts nicht vorher durch einen Live-Patch entfernen.
5. Ausschließlich die alte eMMC-EPHEMERAL-Partition selektiv zurücksetzen und
   neu starten. Boot, STATE und META erhalten; bestehende Cluster-Secrets verwenden.
6. Nach dem Neustart die identifizierte alte Longhorn-Partition erst bei bestätigtem
   Unmount und fehlender Nutzung gezielt löschen. Talos provisioniert danach die SSD.
7. Prüfen, dass `/var` auf der SSD liegt und die gewünschte Kapazität nutzbar ist.
8. CSI, DNS, Netzwerk, Image-Pulls und persistentes Lesen mit einem eigenen temporären
   iSCSI-Test-PVC prüfen; anschließend Test-Pods, PVC, PV und Test-LUN bereinigen.
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

## Pilot-Ausführung

### Vorbereitung

- Die lokale SATA-SSD auf Node 1 wurde über Modell `P3-1TB`, PCIe-/SATA-Buspfad,
  Größe und `/dev/disk/by-id/ata-P3-1TB_0009478001268` identifiziert.
  Die eingebundene iSCSI-LUN ist ein anderes Gerät und darf nicht gelöscht werden.
- Der neue Patch `talos/patches/worker/ephemeral-sata.yaml` selektiert ausschließlich
  `/dev/sda` mit SATA-Transport und Modell `P3-1TB`, außerhalb der Systemdisk.
  `minSize: 100GiB` und `grow: true` nutzen die freiwerdende SSD für `/var`.
- Der Longhorn-Patch ist nicht mehr global. Er bleibt vorläufig ausschließlich
  den unveränderten Nodes 2, 3 und 4 zugeordnet. Nur Node 1 erhält das SSD-Layout.
- Live-MachineConfig, bisherige generierte Konfiguration, Talosconfig, Kubeconfig
  und verschlüsselte Cluster-Secrets sind unter dem ignorierten Verzeichnis
  `.private/ssd-migration-20261113/` lokal außerhalb des Clusters gesichert
  (Verzeichnis 0700, Dateien 0600). Dort liegt auch ein geprüfter etcd-Snapshot.
  Das Verzeichnis enthält Zugangsdaten und darf nicht veröffentlicht werden.
- Der Drain-Dry-Run war erfolgreich. Die drei Flux-Controller laufen auf Node 1;
  sie werden einzeln verschoben und jeweils auf Bereitschaft geprüft.
- Die gezielte Live-Konfiguration für den Pilot basiert auf der gesicherten
  MachineConfig. Der Staged-Dry-Run ändert nur Longhorn-Mount und EPHEMERAL-
  Provisionierung. So werden automatische Konfigurationsformat-Migrationen des
  Generators nicht gleichzeitig mit dem Storage-Umbau angewendet.

### Validierter Talos-Ablauf

Beim Drain war Tautulli zunächst wegen `Insufficient memory` nicht platzierbar:
Der fehlende Memory-Request des Hauptcontainers wurde auf dessen 1-GiB-Limit
gesetzt. Goldilocks/VPA empfahl rund 105 MiB, mit einer oberen Grenze von rund
319 MiB. Für den Pilot wurde der Request daher explizit auf 384 MiB gesetzt;
das Limit bleibt 1 GiB. Der Git-sync-Request wurde entsprechend VPA auf 50 MiB
angehoben. Damit ist der Pod auf den verbleibenden Workern platzierbar, ohne
das Memory-Limit oder die Control-Plane-Isolation zu verändern.

Talos 1.14.6 entfernt beim selektiven Reset die ausgewählte Systempartition
einschließlich ihres GPT-Eintrags. Mit ausschließlich `EPHEMERAL` als Systemziel
bleiben die eMMC-Bootpartitionen, `STATE` und `META` erhalten. Das ist wichtig,
weil ein vorhandenes EPHEMERAL-Label sonst weiterhin auf der eMMC gefunden würde.
Zusätzlich kann genau die identifizierte frühere Longhorn-SSD gelöscht werden.
Der geprüfte Ablauf ist:

1. Descheduler pausieren; Node 1 cordonen und Workloads kontrolliert drainen.
2. Ersatz-Pods sowie Detach der iSCSI-Volumes und VolumeAttachments prüfen.
3. Die minimale Zielkonfiguration mit `apply-config --mode=staged` hinterlegen.
   Noch keine laufenden Mounts ändern.
4. Ausschließlich Node 1 mit `reset --system-labels-to-wipe=EPHEMERAL`
   und `--user-disks-to-wipe=/dev/sda`
   sowie `--reboot` zurücksetzen. Keine globale Reset-Task verwenden.
5. Beim Neustart wird die gestagte Konfiguration übernommen. Beim Pilot bestand
   die alte Longhorn-Partition danach jedoch weiterhin. Talos meldete
   `no disks matched ... not enough space`. Nach erneuter Identitätsprüfung und
   Bestätigung, dass `/dev/sda1` ungemountet und ungenutzt war, wurde sie gezielt
   mit `wipe disk sda1 --drop-partition` entfernt. Anschließend provisionierte
   Talos EPHEMERAL automatisch auf der SSD, ohne weiteren Reboot.
   Den erfolgreichen Reset-Aufruf daher nicht als Beleg einer geleerten SSD
   behandeln; DiscoveredVolumes und MountStatus anschließend prüfen.
6. `/var`, VolumeStatus, Gesamtkapazität, Netzwerk und CSI prüfen; danach einen
   eigenen temporären iSCSI-PVC auf dem Worker testen und erst dann freigeben.

Dieser Ablauf ist nicht unverändert auf die Control Plane anzuwenden.
Ein Reset von `/var` auf der heutigen Control Plane würde auch die dortigen
etcd-Daten betreffen.

Die Reset-API von Talos 1.14.6 akzeptiert für User-Disks nur den erkannten
`dev_path`, hier `/dev/sda`. Der by-id-Alias dient der zusätzlichen
Identitätsprüfung unmittelbar vor dem Aufruf; als Reset-Argument wird er von
der API bereits vor Beginn der Operation abgelehnt.

### Ergebnis von Node 1

- `EPHEMERAL` liegt auf `/dev/sda1`, als XFS unter `/var` gemountet.
  Gemessene Dateisystemkapazität: 1.023,71 GB; unmittelbar nach Provisionierung
  waren rund 1.004 GB verfügbar.
- eMMC-Boot, `STATE` und `META` sind erhalten. Netzwerk- und Cluster-Identität
  blieben erhalten; Talos, Kubelet und Cilium meldeten den Worker wieder bereit.
- CSI-Node-Pod: vier von vier Containern bereit. Auch die übrigen DaemonSets
  starteten wieder auf dem Worker.
- Ein eigener temporärer 1-GiB-PVC mit `iscsi-delete` wurde direkt auf dem noch
  cordonierten Worker eingebunden. Schreiben, `sync` und Lesen waren erfolgreich
  (`CSI_WRITE_READ_OK`). Ein zweiter Pod las dieselben Daten und prüfte Cluster-DNS
  (`DNS_AND_PERSISTENT_READ_OK`). Kein produktiver PVC wurde für den Test umgehängt.
- Die beiden Test-Pods, der Test-PVC und die zugehörige iSCSI-LUN wurden entfernt;
  anschließend wurde der Worker uncordoned.
- Weave GitOps wurde während der Wartung zusätzlich vorübergehend pausiert,
  um CPU auf den übrigen Workern freizugeben. Weave und Descheduler sind nach
  Testbereinigung und Freigabe wieder mit je einer bereiten Replika aktiv.

Für den nächsten Worker vor dem Reset ausreichend Scheduling-Reserve prüfen,
benötigte Controller-Images vorladen und die alte Longhorn-Partition explizit
entfernen, sobald sie sicher ungemountet ist. Der Control-Plane-Wechsel ist
weiterhin nicht durchgeführt.

## Zweiter Worker: Ausführung

Für `talos-test02` wurden die ursprünglichen Replikazahlen vor jeder Änderung
privat gesichert. Vorübergehend auf 0 standen Paperless einschließlich Gotenberg,
Redis und Tika, Calibre-Web, Tautulli, Obsidian, FreshRSS, Spoolman, Weave GitOps
und Descheduler. Nach Speichertest und Freigabe wurden alle elf Deployments
auf die gesicherten Replikazahlen zurückgesetzt und ihre Verfügbarkeit geprüft.
Die Paperless-Abhängigkeiten starteten vor der Hauptanwendung, Descheduler zuletzt.

Die drei Flux-Kerncontroller wurden einzeln auf Node 1 verschoben und jeweils
auf Bereitschaft geprüft. Anschließend wurde Node 2 regulär unter Beachtung der
PodDisruptionBudgets geleert. Ein auf Node 4 wiederholt ausfallender CSI-Controller
wurde ebenfalls auf Node 1 verschoben; Node 4 danach wieder uncordoned.

Das Live-Entfernen der alten Longhorn-Konfiguration verursachte beim Reset einen
Wartezyklus zwischen `UserDiskConfigController`, VolumeConfig und Mount-Status.
Der bereits geleerte und gestoppte Node wurde mit `reboot --mode=force` neu gestartet.
Danach war die eMMC-EPHEMERAL noch vorhanden und die SSD sicher ungemountet.
Die alte Partition `/dev/sda1` wurde nach erneuter Identitäts- und Nutzungsprüfung
mit `wipe disk sda1 --drop-partition` entfernt. Der selektive EPHEMERAL-Reset
wurde nach erneutem Staging erfolgreich wiederholt. Keine Finalizer wurden manuell entfernt.

Talos meldet EPHEMERAL anschließend auf `/dev/sda1` bereit, als XFS unter `/var`
gemountet. Kubernetes erkennt 1.023.708.041.216 Bytes lokalen Speicher und
921.068.800.113 Bytes allocatable. Der erste isolierte iSCSI-Test bestätigt
Schreiben, `sync` und Lesen (`CSI_WRITE_READ_OK`). Ein zweiter Pod bestätigt
persistentes Wiederlesen und Cluster-DNS (`DNS_AND_PERSISTENT_READ_OK`). Beide
Test-Pods, der eigene 1-GiB-PVC und sein PV beziehungsweise seine Test-LUN wurden
anschließend bereinigt. Der Worker ist wieder uncordoned; Talos, Kubelet und
alle System-DaemonSets sind bereit.

### Abschluss von Node 2

- Alle elf pausierten Deployments sind wieder mit ihrer ursprünglichen einen
  Replika verfügbar. Die Baseline und das Verifikationsergebnis liegen privat
  bei den Migrations-Backups; UID und Sollzahlen wurden erneut verglichen.
- Der erste Kaltstart großer Images auf den CM4-CPUs dauerte teilweise lange:
  Paperless benötigte rund 10 Minuten aktiven Pull und 14,5 Minuten einschließlich
  Warteschlange. Der SSD-Wechsel beseitigt den CPU-Engpass nicht.
- Paperless meldete während gleichzeitiger Worker-Initialisierung Starttimeouts;
  nach erfolgreichem Anlauf traten keine weiteren auf. Ein Hintergrundtask lief
  erfolgreich, und der Webserver ist lokal erreichbar und Kubernetes-ready.
- Alle vier Nodes sind Ready und uncordoned. CSI-Controller: 6/6 Container;
  CSI-Node-Pods der drei Worker: jeweils 4/4 Container.
- Die Rollen sind unverändert: Node 3 bleibt die einzige dedizierte Control Plane,
  Node 4 ein Worker. Der Control-Plane-Wechsel und die anschließende SSD-Nutzung
  von Node 3 sind weiterhin eine eigene, noch nicht ausgeführte Etappe.

## Control-Plane-Wechsel: Vorbereitung am 2026-11-14

- Frischer externer etcd-Snapshot auf dem Verwaltungsrechner: 330.555.424 Bytes,
  SHA-256 `d7617955e806cd0fe3796091b86fceb5529f2358480c0dccf5cd07dc18493002`.
  Snapshot, Live-Konfigurationen beider Nodes, Client-Konfiguration und aktuelle
  Deployment-/StatefulSet-Replikazahlen liegen geschützt und Git-ignoriert unter
  `.private/control-plane-migration-20261114/`.
- Ausgangspunkt: ein gesundes etcd-Mitglied auf Node 3. Node 4 ist noch Worker.
- Die minimale Node-4-Zielkonfiguration übernimmt die bestehende Cluster-Identität
  und Control-Plane-Konfiguration von Node 3, aber Hostname, MAC, statische IP und
  Installationskonfiguration von Node 4. VIP `192.168.13.10` kommt hinzu;
  alte Longhorn-Disk- und Bind-Mount-Felder entfallen erst beim Neustart.
  Lokale Validierung und Talos-Staging-Dry-Run sind erfolgreich.
- Live ist `allowSchedulingOnControlPlanes` auf Node 3 noch `true`; dessen
  NoSchedule-Taint schützt ihn aktuell. Node 4 erhält ausdrücklich `false`,
  entsprechend der bereits vorhandenen Controller-Konfiguration im Repository.
- Die vollständige Generierung mit `task talos:generate-config` war nach erneuter
  Freigabe von 1Password erfolgreich. Generierte und minimale Konfiguration bestehen
  die lokale Validierung; Cluster-ID, PKI und der in `KubeEtcdEncryptionConfig`
  ausgelagerte Verschlüsselungsschlüssel stimmen überein. Die generierten neuen
  Dokumenttypen werden bei diesem Rollenwechsel nicht zusätzlich live migriert.
  Am laufenden Cluster wurde zu diesem Vorbereitungsstand noch keine Rolle geändert.
- Die Ressourcenanforderungen von Node 4 passen mit geringer Reserve auf Nodes 1
  und 2. Infrastruktur-Images werden vorab auf Node 1 geladen. Descheduler und
  Weave sollen während des Umzugs mit gesicherter Replikazahl pausieren.
- Talos 1.14.6 nimmt neue etcd-Mitglieder zuerst als Learner auf und befördert sie
  nach Synchronisierung automatisch. Geprüft im
  [passenden Talos-Quellcode](https://github.com/siderolabs/talos/blob/v1.14.6/internal/app/machined/pkg/system/services/etcd.go).
- Der Übergang verwendet vorübergehend zwei erreichbare stimmberechtigte etcd-Mitglieder; das
  bringt keine Ausfalltoleranz. Node 3 bleibt aktiv, bis Node 4 vollständig
  synchronisiert, API/VIP geprüft und das reguläre Verlassen des alten Mitglieds
  vorbereitet ist. Ein zusätzlich umgewandelter SSD-Worker würde weitere Rollen-
  und Speicherwechsel verursachen und wird für diesen kurzen Übergang nicht vorgesehen.

## Referenzen

- [Talos 1.14: Release Notes und dedizierte System-Volumes](https://github.com/siderolabs/talos/discussions/14230)
- [Talos VolumeConfig: Validierung bestehender System-Volumes](https://pkg.go.dev/github.com/siderolabs/talos/pkg/machinery/config/types/block#VolumeConfigV1Alpha1.RuntimeValidate)
- [Cluster-Konfiguration](../talos/talconfig.yaml)
- [Backups](backups.md) und [Disaster Recovery](dr.md)
- [Kyverno-Migration und Live-Fix](kyverno-cel-migration.md)
