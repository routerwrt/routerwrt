export function render(root) {
    root.innerHTML = `
        <section class="page">
            <header class="page-header">
                <div>
                    <h1>Firmware Upgrade</h1>
                    <p>Install a RouterWRT sysupgrade image.</p>
                </div>
            </header>

            <div class="card">
                <h2>⬆️ Firmware</h2>

                <form id="firmware-form">
                    <label class="field">
                        <span>Sysupgrade image</span>
                        <input
                            id="firmware-file"
                            name="firmware"
                            type="file"
                            accept=".bin"
                            required>
                    </label>

                    <label class="check">
                        <input
                            id="keep-config"
                            type="checkbox"
                            checked>
                        <span>Keep configuration</span>
                    </label>

                    <div id="firmware-status"
                         class="status"></div>

                    <button type="submit"
                            class="button">
                        Check firmware
                    </button>
                </form>
            </div>
        </section>
    `;

    const form = root.querySelector("#firmware-form");
    const file = root.querySelector("#firmware-file");
    const keep = root.querySelector("#keep-config");
    const status = root.querySelector("#firmware-status");

    form.addEventListener("submit", async event => {
        event.preventDefault();

        if (!file.files.length)
            return;

        const data = new FormData();
        data.append("firmware", file.files[0]);

        status.textContent = "Uploading and checking firmware…";

        try {
            const response = await fetch(
                "/cgi-bin/upgrade.cgi",
                {
                    method: "POST",
                    body: data
                }
            );

            const result = await response.json();

            if (!result.ok)
                throw new Error(result.error || "Firmware rejected");

            const size =
                (result.size / 1024 / 1024).toFixed(2);

            status.innerHTML = `
                <p>
                    Firmware image valid<br>
                    Size: ${size} MiB
                </p>

                <button
                    id="flash-button"
                    type="button"
                    class="button danger">
                    Flash firmware
                </button>
            `;

            root.querySelector("#flash-button")
                .addEventListener("click", () => {
                    flashFirmware(root, keep.checked);
                });

        } catch (error) {
            status.textContent =
                "Error: " + error.message;
        }
    });
}


async function flashFirmware(root, keepConfig) {
    const status =
        root.querySelector("#firmware-status");

    if (!confirm(
        "Flash this firmware now?\n\n" +
        "Do not power off the router during the upgrade."
    )) {
        return;
    }

    status.textContent = "Starting firmware upgrade…";

    try {
        const response = await fetch(
            "/cgi-bin/upgrade.cgi?action=flash&keep=" +
            (keepConfig ? "1" : "0"),
            {
                method: "POST"
            }
        );

        const result = await response.json();

        if (!result.ok)
            throw new Error(result.error || "Upgrade failed");

        status.innerHTML = `
            <strong>Upgrade started.</strong>
            <p>
                The router will reboot automatically.
                Do not disconnect power.
            </p>
        `;

    } catch (error) {
        /*
         * There is an interesting sysupgrade case here:
         *
         * the router may kill httpd/network before fetch()
         * receives the complete response.
         *
         * Therefore a lost connection immediately after
         * starting sysupgrade isn't necessarily failure.
         */
        status.innerHTML = `
            <strong>Upgrade started.</strong>
            <p>
                Connection to the router was lost.
                It may now be rebooting.
            </p>
        `;
    }
}
