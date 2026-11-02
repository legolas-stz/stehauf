# Stehauf

Eine kleine macOS-App, die dich nach 55 Minuten am Mac mit einem Vollbild-Hinweis ans Aufstehen erinnert. Der Hinweis ist ein eigenes Fenster und keine Mitteilung, erscheint also auch während eines Fokus.

- **Keine Unterbrechung in Meetings:** Solange Mikrofon oder Kamera benutzt werden, wartet die Erinnerung und kommt erst danach.
- **Keine Berechtigungen:** Stehauf fragt nur ab, ob die Geräte gerade laufen, und öffnet sie nie. macOS zeigt deshalb keine Abfrage.
- **Pausen zählen:** 5 Minuten mit gesperrtem Bildschirm, schlafendem Display oder im Ruhezustand setzen den Timer zurück, 20 Minuten ohne Eingabe ebenfalls.
- **Sparsam:** Eine Prüfung pro Minute, kein Dock-Symbol, keine Menüleiste, keine Abhängigkeiten.

Schließen lässt sich der Hinweis per Klick auf den Button oder mit Esc. Enter schließt ihn bewusst nicht, damit er beim Tippen nicht versehentlich verschwindet.

## Installation

Voraussetzungen: macOS 14.2 oder neuer und die Xcode Command Line Tools (`xcode-select --install`).

```sh
git clone https://github.com/legolas-stz/stehauf.git
cd stehauf
./install.sh
```

Stehauf startet danach automatisch bei jedem Login. Mit `./test.sh` siehst du den Hinweis sofort, mit `./uninstall.sh` entfernst du alles wieder.

## Einstellungen

Die Werte werden beim Installieren gesetzt, alle in Minuten:

```sh
INTERVAL_MIN=45 BREAK_MIN=5 IDLE_RESET_MIN=20 ./install.sh
```

| Variable | Standard | Bedeutung |
| --- | --- | --- |
| `INTERVAL_MIN` | 55 | Zeit am Mac bis zur Erinnerung |
| `BREAK_MIN` | 5 | So lange gesperrt oder schlafend gilt als Pause |
| `IDLE_RESET_MIN` | 20 | So lange ohne Eingabe gilt als Pause (0 = aus) |

## Gut zu wissen

Jede App, die das Mikrofon offen hält, gilt als Meeting, auch ein vergessener Browser-Tab oder ein Diktier-Tool. Bleibt die Erinnerung aus, ist das die wahrscheinlichste Ursache.

## Lizenz

[MIT](LICENSE)
