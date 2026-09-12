/*
 * RouterWRT core.js
 *
 * apps.js format:
 *
 * export const apps = [
 *   ["firmware", "⬆️", "Firmware",
 *    "/firmware", "/apps/firmware/page.js"],
 *
 *   ["logs", "📜", "Logs",
 *    "/logs", "/apps/logs/page.js"]
 * ];
 */

import { apps } from "./apps.js";

const $ = (selector, root = document) =>
    root.querySelector(selector);

const content = $("#content");
const nav = $("#app-nav");
const appsGrid = $("#apps-grid");
const themeSelect = $("#theme");


/*
 * Build internal app map from generated apps.js
 */
const appMap = new Map();

for (const entry of apps) {
    const [id, icon, title, route, modulePath] = entry;

    appMap.set(route, {
        id,
        icon,
        title,
        route,
        modulePath
    });
}


/*
 * Theme
 */
function applyTheme(theme) {
    const root = document.documentElement;

    if (theme === "auto")
        root.removeAttribute("data-theme");
    else
        root.setAttribute("data-theme", theme);

    localStorage.setItem("routerwrt-theme", theme);
}


function initTheme() {
    if (!themeSelect)
        return;

    const saved =
        localStorage.getItem("routerwrt-theme") || "auto";

    themeSelect.value = saved;
    applyTheme(saved);

    themeSelect.addEventListener("change", event => {
        applyTheme(event.target.value);
    });
}


/*
 * Navigation
 */
function makeNavLink(icon, title, route) {
    const a = document.createElement("a");

    a.href = "#" + route;
    a.dataset.route = route;

    a.innerHTML = `
        <span class="nav-icon">${icon}</span>
        <span>${title}</span>
    `;

    return a;
}


function buildNavigation() {
    if (!nav)
        return;

    nav.replaceChildren();

    /*
     * Dashboard is part of RouterWRT core.
     */
    nav.appendChild(
        makeNavLink("🏠", "Dashboard", "/")
    );

    /*
     * Everything else comes from apps.js.
     */
    for (const app of appMap.values()) {
        nav.appendChild(
            makeNavLink(
                app.icon,
                app.title,
                app.route
            )
        );
    }
}


/*
 * Dashboard Apps widget
 */
function buildAppsWidget() {
    if (!appsGrid)
        return;

    appsGrid.replaceChildren();

    for (const app of appMap.values()) {
        const a = document.createElement("a");

        a.className = "app-icon";
        a.href = "#" + app.route;

        a.innerHTML = `
            <span class="app-emoji">${app.icon}</span>
            <span>${app.title}</span>
        `;

        appsGrid.appendChild(a);
    }
}


/*
 * Current route:
 *
 *   #/firmware -> /firmware
 *   #/logs     -> /logs
 *   no hash    -> /
 */
function currentRoute() {
    let route = location.hash.slice(1);

    if (!route)
        return "/";

    if (!route.startsWith("/"))
        route = "/" + route;

    return route;
}


function markActiveRoute(route) {
    if (!nav)
        return;

    for (
        const link of
        nav.querySelectorAll("a[data-route]")
    ) {
        link.classList.toggle(
            "active",
            link.dataset.route === route
        );
    }
}


/*
 * Dashboard
 *
 * Dashboard HTML stays in index.html.
 */
function renderDashboard() {
    const dashboard = $("#dashboard");

    if (dashboard)
        dashboard.hidden = false;

    if (content)
        content.hidden = true;
}


/*
 * Currently loaded app module.
 *
 * An app may optionally export:
 *
 *   destroy()
 *
 * useful later for clearing polling timers etc.
 */
let currentModule = null;


function destroyCurrentApp() {
    if (
        currentModule &&
        typeof currentModule.destroy === "function"
    ) {
        try {
            currentModule.destroy();
        } catch (error) {
            console.warn(
                "RouterWRT app cleanup failed:",
                error
            );
        }
    }

    currentModule = null;
}


/*
 * Load app on demand.
 */
async function renderApp(app) {
    const dashboard = $("#dashboard");

    if (dashboard)
        dashboard.hidden = true;

    if (!content)
        return;

    content.hidden = false;

    destroyCurrentApp();

    content.innerHTML = `
        <section class="card">
            <p>
                Loading ${escapeHtml(app.title)}…
            </p>
        </section>
    `;

    try {
        /*
         * Browser only fetches page.js when the user
         * actually opens this app.
         */
        const module =
            await import(app.modulePath);

        if (typeof module.render !== "function") {
            throw new Error(
                "App does not export render(root)"
            );
        }

        content.replaceChildren();

        module.render(content);

        currentModule = module;

    } catch (error) {
        console.error(error);

        content.innerHTML = `
            <section class="card">
                <h2>App failed to load</h2>

                <p>
                    Unable to load
                    <strong>
                        ${escapeHtml(app.title)}
                    </strong>.
                </p>

                <pre class="log-view">${
                    escapeHtml(
                        error.message ||
                        String(error)
                    )
                }</pre>
            </section>
        `;
    }
}


/*
 * Unknown route.
 */
function renderNotFound(route) {
    const dashboard = $("#dashboard");

    destroyCurrentApp();

    if (dashboard)
        dashboard.hidden = true;

    if (!content)
        return;

    content.hidden = false;

    content.innerHTML = `
        <section class="card">
            <h2>Page not found</h2>

            <p>
                No RouterWRT app provides
                <code>${escapeHtml(route)}</code>.
            </p>

            <p>
                <a href="#/">
                    Return to dashboard
                </a>
            </p>
        </section>
    `;
}


/*
 * Main router.
 */
async function route() {
    const path = currentRoute();

    markActiveRoute(path);

    if (path === "/") {
        destroyCurrentApp();
        renderDashboard();
        return;
    }

    const app = appMap.get(path);

    if (!app) {
        renderNotFound(path);
        return;
    }

    await renderApp(app);
}


/*
 * Used only where text is inserted into generated HTML.
 */
function escapeHtml(value) {
    return String(value)
        .replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;")
        .replaceAll('"', "&quot;")
        .replaceAll("'", "&#39;");
}


/*
 * Start RouterWRT UI.
 */
function init() {
    initTheme();

    buildNavigation();
    buildAppsWidget();

    window.addEventListener(
        "hashchange",
        route
    );

    route();
}


init();
