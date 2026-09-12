export function render(root) {
    root.innerHTML = `
        <section class="page">
            <header class="page-header">
                <div>
                    <h1>System Log</h1>
                    <p>Kernel ring buffer</p>
                </div>

                <button
                    id="refresh-log"
                    class="button">
                    Refresh
                </button>
            </header>

            <div class="card">
                <pre id="kernel-log"
                     class="log-output">Loading…</pre>
            </div>
        </section>
    `;

    const output =
        root.querySelector("#kernel-log");

    async function refresh() {
        try {
            const response = await fetch(
                "/cgi-bin/dmesg.sh?_=" + Date.now()
            );

            if (!response.ok)
                throw new Error("HTTP " + response.status);

            output.textContent =
                await response.text();

            output.scrollTop =
                output.scrollHeight;

        } catch (error) {
            output.textContent =
                "Unable to read kernel log.";
        }
    }

    root.querySelector("#refresh-log")
        .addEventListener("click", refresh);

    refresh();
}
