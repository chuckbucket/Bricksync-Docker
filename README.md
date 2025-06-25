The BrickOwl/BrickLink synchronization software, BrickSync, is now open source!
http://www.bricksync.net/

Restrictions related to registration have been removed from the 1.7.1 builds (sorry, can't build OSX binaries, I don't have access to an OSX box...).

Direct link to the source code:
http://www.bricksync.net/bricksync-src.tar.gz

It's being released under a very permissible attribution license, more precisely:

* This software is provided 'as-is', without any express or implied
* warranty. In no event will the authors be held liable for any damages
* arising from the use of this software.
*
* Permission is granted to anyone to use this software for any purpose,
* including commercial applications, and to alter it and redistribute it
* freely, subject to the following restrictions:
*
* 1. The origin of this software must not be misrepresented; you must not
* claim that you wrote the original software. If you use this software
* in a product, an acknowledgment in the product documentation would be
* appreciated but is not required.
* 2. Altered source versions must be plainly marked as such, and must not be
* misrepresented as being the original software.
* 3. This notice may not be removed or altered from any source distribution.

The source code is written in C with GNUisms, therefore it will compile with GCC, mingw64, Clang or the Intel Compiler. The only dependency is OpenSSL for socket encryption. The source code includes a build-win64 subdirectory with headers and DLLs for OpenSSL on Windows; the code therefore will build with a plain freshly installed mingw64 (select x86-64 as target when installing mingw64, not i686).

Direct link to the mingw64 installer (mingw being the famous GCC compiler ported to Windows):
https://sourceforge.net/projects/mingw-w64/files/Toolchains targetting Win32/Personal Builds/mingw-builds/installer/mingw-w64-install.exe/download
You'll have to edit the compile-win64.bat script to set the PATH environment variable to the /bin subdirectory of wherever you installed mingw64.

Happy building, and coding :)

## Running with Docker

This project can be built and run as a Docker container.

### Automated Builds

A GitHub Actions workflow is set up to automatically build the Docker image on every push or pull request to the `main` branch. This ensures that the Dockerfile is always up-to-date and the application compiles correctly within the Docker environment. You can see the status of these builds in the "Actions" tab of the GitHub repository.

### Local Development and Usage

To build and run the Docker image locally:

1.  **Ensure Docker is installed** on your system.
2.  **Clone the repository.**
3.  **Navigate to the project directory** in your terminal.
4.  **Build the image:**
    ```bash
    docker build -t bricksync-app .
    ```
5.  **Run the application:**
    The application uses a `bricksync.conf` file for configuration.
    *   A default `bricksync.conf` is included in the image.
    *   To use your own configuration, create a `bricksync.conf` file in your project directory (or elsewhere) and mount it into the container.

    Example command to run with a custom configuration file located in the current directory:
    ```bash
    docker run --rm -it -v "$(pwd)/bricksync.conf:/app/bricksync.conf" bricksync-app
    ```
    If you want to use the default configuration baked into the image (not recommended for real use as you'll want to set your API keys):
    ```bash
    docker run --rm -it bricksync-app
    ```
    The application also creates a `data/pgcache` directory for its price guide cache. To persist this data across container runs, you can mount a local directory to `/app/data`:
    ```bash
    docker run --rm -it \
      -v "$(pwd)/bricksync.conf:/app/bricksync.conf" \
      -v "$(pwd)/my_bricksync_data:/app/data" \
      bricksync-app
    ```
    (Make sure to create `my_bricksync_data` directory locally first if you use this command).

    You can pass additional command-line arguments to `bricksync` after the image name:
    ```bash
    docker run --rm -it bricksync-app --help
    ```

### Configuration (`bricksync.conf`)

The `bricksync.conf` file contains various settings for the application, including API keys for BrickLink and BrickOwl. The default configuration file (`bricksync.conf.txt` in the repository) is copied into the image as `/app/bricksync.conf`.

**It is strongly recommended to use a custom `bricksync.conf` file with your actual API keys and settings.** You can do this by creating your own `bricksync.conf` and mounting it as shown in the "Run the application" examples above. Refer to `bricksync.conf.txt` for all available options.
