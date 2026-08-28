# Contributors

*Everyone who's put time into testing, debugging, or improving this
proposal — not just code contributions. If you found a bug, tested on
a platform we hadn't covered, or helped diagnose something, you belong
here.*

## Contributeurs

*Toute personne ayant consacré du temps à tester, déboguer ou
améliorer cette proposition — pas seulement des contributions de code.
Si tu as trouvé un bug, testé sur une plateforme qu'on n'avait pas
couverte, ou aidé à diagnostiquer quelque chose, ta place est ici.*

---

| Name / Handle | Contribution | Date |
| --- | --- | --- |
| [Cédric Ribier](https://github.com/cedric-ribier) | Author — build, provisioning scripts, documentation | 2026-08 |

---

## How to add yourself / Comment s'ajouter

Open a pull request adding a row to the table above. One line, your
own words — a short description is enough (e.g. *"Tested build +
provider install on Windows 11 / VirtualBox — found and helped
diagnose the CRLF line-ending bug"*).

Ouvre une pull request ajoutant une ligne au tableau ci-dessus. Une
ligne, tes propres mots — une courte description suffit (ex. *"Testé
build + installation des providers sous Windows 11 / VirtualBox — a
trouvé et aidé à diagnostiquer le bug de fin de ligne CRLF"*).

```bash
git clone https://github.com/cedric-ribier/dsoxlab-appliance.git
cd dsoxlab-appliance
git checkout -b add-contributor-<your-name>
# edit CONTRIBUTORS.md, add your row
git add CONTRIBUTORS.md
git commit -m "Add <your name> to CONTRIBUTORS.md"
git push origin add-contributor-<your-name>
# then open a PR on GitHub from your fork or this branch
```

No fork required if you already have push access to a branch; a fork
is the standard path otherwise — either works, GitHub's PR interface
handles both the same way.
