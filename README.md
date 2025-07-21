The BrickOwl/BrickLink synchronization software, BrickSync, is now open source!
http://www.bricksync.net/

Restrictions related to registration have been removed from the 1.7.1 builds (sorry, can't build OSX binaries, I don't have access to an OSX box...).

Direct link to the source code:
http://www.bricksync.net/bricksync-src.tar.gz

It's being released under a very permissible attribution license, more precisely:

- This software is provided 'as-is', without any express or implied
- warranty. In no event will the authors be held liable for any damages
- arising from the use of this software.
-
- Permission is granted to anyone to use this software for any purpose,
- including commercial applications, and to alter it and redistribute it
- freely, subject to the following restrictions:
-
- 1. The origin of this software must not be misrepresented; you must not
- claim that you wrote the original software. If you use this software
- in a product, an acknowledgment in the product documentation would be
- appreciated but is not required.
- 2. Altered source versions must be plainly marked as such, and must not be
- misrepresented as being the original software.
- 3. This notice may not be removed or altered from any source distribution.

The source code is written in C with GNUisms, therefore it will compile with GCC, mingw64, Clang or the Intel Compiler. The only dependency is OpenSSL for socket encryption. The source code includes a build-win64 subdirectory with headers and DLLs for OpenSSL on Windows; the code therefore will build with a plain freshly installed mingw64 (select x86-64 as target when installing mingw64, not i686).

Direct link to the mingw64 installer (mingw being the famous GCC compiler ported to Windows):
https://sourceforge.net/projects/mingw-w64/files/Toolchains targetting Win32/Personal Builds/mingw-builds/installer/mingw-w64-install.exe/download
You'll have to edit the compile-win64.bat script to set the PATH environment variable to the /bin subdirectory of wherever you installed mingw64.

Happy building, and coding :)

## Running with Docker

This project includes a `docker/Dockerfile` to build and run BrickSync as a Docker container with a graphical user interface (GUI) accessible via VNC and a web browser (noVNC).

### Automated Builds

A GitHub Actions workflow is set up to automatically build the Docker image (`ghcr.io/chuckbucket/bricksync-docker:latest`) on every push or pull request to the `main` branch. This ensures that the Dockerfile is always up-to-date and the application compiles correctly within the Docker environment. You can see the status of these builds in the "Actions" tab of the GitHub repository.

### Building the Image Locally

If you prefer to build the image yourself:

1.  **Ensure Docker is installed** on your system.
2.  **Clone the repository.**
3.  **Navigate to the project directory** (the root of this repository) in your terminal.
4.  **Build the image:**
    ```bash
    docker build -t bricksync-gui -f docker/Dockerfile .
    ```
    (You can replace `bricksync-gui` with your preferred image name).

### Running BrickSync (GUI Mode via VNC/noVNC)

The Docker image runs BrickSync within a lightweight OpenBox desktop environment (featuring `pcmanfm` for file/desktop management and `tint2` for the panel), accessible via VNC (port `5901` inside the container) and noVNC (port `6901` inside the container for web browser access).

**Example `docker run` command:**

```bash
docker run \
  -d \
  --name='Bricksync' \
  --net='bridge' \
  --pids-limit 2048 \
  -e TZ="America/Denver" \
  -e HOST_OS="Unraid" \
  -e HOST_HOSTNAME="MCP" \
  -e HOST_CONTAINERNAME="Bricksync" \
  -e 'BRICKSYNC_BRICKLINK_CONSUMERKEY'='YOUR_BL_CONSUMER_KEY' \
  -e 'BRICKSYNC_BRICKLINK_CONSUMERSECRET'='YOUR_BL_CONSUMER_SECRET' \
  -e 'BRICKSYNC_BRICKLINK_TOKEN'='YOUR_BL_TOKEN' \
  -e 'BRICKSYNC_BRICKLINK_TOKENSECRET'='YOUR_BL_TOKEN_SECRET' \
  -e 'BRICKSYNC_BRICKOWL_KEY'='YOUR_BRICKOWL_API_KEY' \
  -e 'VNC_RESOLUTION'='1280x700' \
  -p '4459:6901/tcp' \
  -v '/path/on/host/bricksync_config':'/mnt/config':'rw' \
  -v '/path/on/host/bricksync_data':'/app/data':'rw' \
  'ghcr.io/chuckbucket/bricksync-docker:latest'
```

**Explanation of `docker run` options:**

- `-d`: Run the container in detached mode (in the background).
- `--name='Bricksync'`: Assign a name to your container for easier management.
- `--net='bridge'`: Use the default bridge network.
- `--pids-limit 2048`: Set a limit on the number of processes the container can run.
- `-e TZ="America/Denver"`: Set the timezone for the container. Replace with your local timezone.
- `-e HOST_OS="Unraid"`, `-e HOST_HOSTNAME="MCP"`, `-e HOST_CONTAINERNAME="Bricksync"`: Optional environment variables for host information, potentially used by local scripts or for identification.
- `-e 'BRICKSYNC_BRICKLINK_CONSUMERKEY'='YOUR_BL_CONSUMER_KEY'`: Your BrickLink Consumer Key. **Replace placeholder.**
- `-e 'BRICKSYNC_BRICKLINK_CONSUMERSECRET'='YOUR_BL_CONSUMER_SECRET'`: Your BrickLink Consumer Secret. **Replace placeholder.**
- `-e 'BRICKSYNC_BRICKLINK_TOKEN'='YOUR_BL_TOKEN'`: Your BrickLink Token. **Replace placeholder.**
- `-e 'BRICKSYNC_BRICKLINK_TOKENSECRET'='YOUR_BL_TOKEN_SECRET'`: Your BrickLink Token Secret. **Replace placeholder.**
- `-e 'BRICKSYNC_BRICKOWL_KEY'='YOUR_BRICKOWL_API_KEY'`: Your BrickOwl API Key. **Replace placeholder.**
  - _Note on API Keys:_ Providing API keys via environment variables is recommended for Docker deployments. These will be written into the `bricksync.conf.txt` file inside the container at startup.
- `-e 'VNC_RESOLUTION'='1280x700'`: Set the screen resolution for the VNC desktop (e.g., `1280x720`, `1920x1080`).
- `-p '4459:6901/tcp'`: Map port `4459` on your host to port `6901` (noVNC web access) in the container. You can then access BrickSync via a web browser at `http://<your_docker_host_ip>:4459`.
  - If you also want direct VNC client access, you can add another port mapping like `-p '5901:5901/tcp'` and connect with a VNC viewer to `<your_docker_host_ip>:5901`.
- `-v '/path/to/host/config':'/mnt/config':'rw'`: **(Optional)** Mount a directory from your host to `/mnt/config` inside the container. Place a `bricksync.conf` file here to be used as the base configuration.
- `-v '/path/to/host/data':'/app/data':'rw'`: **(Recommended)** Mount a directory from your host to `/app/data`. This will store persistent application data, such as logs, the price guide cache, and the effective `bricksync.conf.txt`. This ensures your data and settings persist across container restarts.
- `'ghcr.io/chuckbucket/bricksync-docker:latest'`: The Docker image to use. Replace with `bricksync-gui` (or your custom name) if you built it locally.

**Accessing BrickSync:**

- **Via Web Browser (noVNC):** Open `http://<your_docker_host_ip>:<host_port_for_6901>` (e.g., `http://localhost:4459` if running Docker locally and used the example).
- **Via VNC Client:** Connect to `<your_docker_host_ip>:<host_port_for_5901>` (e.g., `localhost:5901` if you mapped port 5901). No password is set by default for VNC access.

### Configuration (`bricksync.conf.txt`)

BrickSync uses a configuration file named `bricksync.conf.txt` (copied from `bricksync.conf.txt` in the repository root if a user-provided one isn't found).

**Configuration Methods:**

1.  **Environment Variables (Recommended for API Keys):** As shown in the `docker run` example, you can set API keys and other parameters using `-e` flags. These will override values in the `bricksync.conf.txt` file. Refer to `docker/entrypoint.sh` for all supported `BRICKSYNC_*` environment variables.
2.  **Mounted Configuration File (Recommended for Base Settings):**
    - Create a directory on your host (e.g., `/my/bricksync/config`).
    - Place your customized `bricksync.conf` file (you can copy `bricksync.conf.txt` from the repo as a template) into this directory.
    - Mount this directory to `/mnt/config` in the container (e.g., `-v /my/bricksync/config:/mnt/config:rw`). The `entrypoint.sh` script will copy this file to `/app/data/bricksync.conf.txt` for the application to use.
3.  **Default Configuration:** If no environment variables are set and no configuration file is mounted to `/mnt/config`, a default `bricksync.conf.txt` (from the image) will be used. **This default file will not have your API keys and is not suitable for production use.**

**It is strongly recommended to manage your API keys using environment variables and other persistent settings via a mounted configuration file.**

The effective configuration file used by the application at runtime is located at `/app/data/bricksync.conf.txt` within the container.

### Command-Line Interface (CLI) Usage (Alternative)

While the primary Dockerfile (`docker/Dockerfile`) builds a GUI application, BrickSync can also be run as a command-line tool. The information below pertains to such a use case, potentially with a different, simpler Dockerfile focused on CLI operation.

If you were to run BrickSync in a CLI-only Docker container (assuming such an image `bricksync-cli-app` exists):

1.  **Run with a custom configuration file:**

    ```bash
    # Assuming bricksync.conf is in your current directory
    docker run --rm -it \
      -v "$(pwd)/bricksync.conf:/app/bricksync.conf" \
      -v "$(pwd)/my_bricksync_data:/app/data" \
      bricksync-cli-app
    ```

    _(Ensure `my_bricksync_data` directory exists locally.)_

2.  **Use default configuration (not for production):**

    ```bash
    docker run --rm -it bricksync-cli-app
    ```

3.  **Pass command-line arguments:**
    `bash
docker run --rm -it bricksync-cli-app --help
`
    Refer to `bricksync.conf.txt` for all available configuration options if preparing a file for CLI use.
