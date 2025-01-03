#!/bin/bash

set -euo pipefail

# Check if PIXI_ENV is set
if [ -z "${PIXI_ENV:-}" ]; then
  echo "Error: PIXI_ENV is not set."
  exit 1
fi

# Create script to activate the environment
echo "#!/bin/bash" > /usr/local/bin/before-notebook.d/10activate-env.sh
pixi shell-hook -e ${PIXI_ENV} >> /usr/local/bin/before-notebook.d/10activate-env.sh
chmod +x /usr/local/bin/before-notebook.d/10activate-env.sh

# Create shell wrapper that activates the environment
echo "#!/bin/bash" > /usr/local/bin/wrapper.sh
pixi shell-hook -e ${PIXI_ENV} >> /usr/local/bin/wrapper.sh
echo "exec \"\$@\"" >> /usr/local/bin/wrapper.sh
chmod +x /usr/local/bin/wrapper.sh
