#!/usr/bin/env bash
# Install this skill for a specific agent, or vendor it into a project.
#
# ASCII only: macOS bash 3.2 folds the bytes of a non-ASCII character following a
# variable into the variable name, which fails under `set -u`.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
NAME="local-first-pwa"

usage() {
  cat <<USAGE
Install the ${NAME} skill.

  ./install.sh kiro              link into ~/.kiro/skills/${NAME}
  ./install.sh claude            link into ~/.claude/skills/${NAME}
  ./install.sh cursor            copy the rule into ~/.cursor/rules/
  ./install.sh project <path>    vendor the routers into a project at <path>
  ./install.sh list              show what is installed where

Global installs use a symlink, so pulling this repo updates every agent at once.
A project install copies small router files that point back here; the method is
never copied, because copies drift.
USAGE
}

link_into() {
  target_dir="$1"
  mkdir -p "$(dirname "${target_dir}")"
  if [ -L "${target_dir}" ]; then
    rm "${target_dir}"
  elif [ -e "${target_dir}" ]; then
    echo "refusing to replace a real directory: ${target_dir}"
    echo "move it aside first, then re-run"
    exit 1
  fi
  ln -s "${HERE}" "${target_dir}"
  echo "linked ${target_dir} -> ${HERE}"
}

case "${1:-}" in
  kiro)
    link_into "${HOME}/.kiro/skills/${NAME}"
    echo "Kiro will auto-activate it when a request matches the description in SKILL.md."
    ;;
  claude)
    link_into "${HOME}/.claude/skills/${NAME}"
    echo "Claude Code reads SKILL.md frontmatter and loads it on demand."
    ;;
  cursor)
    mkdir -p "${HOME}/.cursor/rules"
    cp "${HERE}/.cursor/rules/${NAME}.mdc" "${HOME}/.cursor/rules/${NAME}.mdc"
    echo "copied ~/.cursor/rules/${NAME}.mdc"
    echo "NOTE: it points at this repo by relative path, so it works best as a project install."
    ;;
  project)
    DEST="${2:-}"
    [ -n "${DEST}" ] || { echo "usage: ./install.sh project <path>"; exit 1; }
    [ -d "${DEST}" ] || { echo "no such directory: ${DEST}"; exit 1; }
    mkdir -p "${DEST}/.cursor/rules" "${DEST}/.github"
    REF_DIR="reference-${NAME}"
    # Namespaced so it cannot collide with a project's own reference/ folder.
    # Every vendored file's links are rewritten to match, or they would 404.
    rm -rf "${DEST}/${REF_DIR}"
    cp -R "${HERE}/reference" "${DEST}/${REF_DIR}"
    echo "wrote ${DEST}/${REF_DIR}/ (6 reference docs)"

    retarget() {
      sed -e "s|reference/|${REF_DIR}/|g" \
          -e "s|\./scripts/scaffold\.sh|${NAME}/scripts/scaffold.sh|g" "$1"
    }

    for f in AGENTS.md CLAUDE.md SKILL.md .windsurfrules .clinerules; do
      if [ -e "${DEST}/${f}" ]; then
        echo "skipping existing ${DEST}/${f} -- merge by hand"
      else
        retarget "${HERE}/${f}" > "${DEST}/${f}"
        echo "wrote ${DEST}/${f}"
      fi
    done
    retarget "${HERE}/.cursor/rules/${NAME}.mdc" > "${DEST}/.cursor/rules/${NAME}.mdc"
    echo "wrote ${DEST}/.cursor/rules/${NAME}.mdc"
    if [ -e "${DEST}/.github/copilot-instructions.md" ]; then
      echo "skipping existing ${DEST}/.github/copilot-instructions.md -- merge by hand"
    else
      retarget "${HERE}/.github/copilot-instructions.md" > "${DEST}/.github/copilot-instructions.md"
      echo "wrote ${DEST}/.github/copilot-instructions.md"
    fi

    echo
    echo "Vendored into ${DEST}."
    echo "The scaffold itself is not copied; run it from this repo:"
    echo "  ${HERE}/scripts/scaffold.sh <target-dir> \"App Name\""
    ;;
  list)
    for p in "${HOME}/.kiro/skills/${NAME}" "${HOME}/.claude/skills/${NAME}"; do
      if [ -L "${p}" ]; then echo "link    ${p} -> $(readlink "${p}")"
      elif [ -d "${p}" ]; then echo "copy    ${p}"
      else echo "absent  ${p}"; fi
    done
    if [ -f "${HOME}/.cursor/rules/${NAME}.mdc" ]; then
      echo "copy    ${HOME}/.cursor/rules/${NAME}.mdc"
    else
      echo "absent  ${HOME}/.cursor/rules/${NAME}.mdc"
    fi
    ;;
  ""|-h|--help|help) usage ;;
  *) echo "unknown target: ${1}"; echo; usage; exit 1 ;;
esac
