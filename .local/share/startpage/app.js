// Startpage Application

(function() {
    'use strict';

    // Configuration
    let config = null;

    // Initialize the application
    async function init() {
        updateClock();
        setInterval(updateClock, 1000);

        try {
            config = await loadJSON('config.json');
            initSearch();
            renderLinks();
            renderServices();
        } catch (e) {
            console.error('Failed to load config:', e);
        }

        // Load dynamic data
        loadSystemStats();
        loadServiceStatus();

        // Refresh data periodically (every 30 seconds)
        setInterval(loadSystemStats, 30000);
        setInterval(loadServiceStatus, 30000);
    }

    // Load JSON file
    async function loadJSON(path) {
        const response = await fetch(path);
        if (!response.ok) throw new Error(`Failed to load ${path}`);
        return response.json();
    }

    // Update clock and date
    function updateClock() {
        const now = new Date();

        const hours = now.getHours().toString().padStart(2, '0');
        const minutes = now.getMinutes().toString().padStart(2, '0');
        document.getElementById('clock').textContent = `${hours}:${minutes}`;

        const options = { weekday: 'long', month: 'long', day: 'numeric' };
        document.getElementById('date').textContent = now.toLocaleDateString('en-US', options);
    }

    // Initialize search functionality
    function initSearch() {
        const form = document.getElementById('search-form');
        const input = document.getElementById('search-input');

        if (config.search) {
            input.placeholder = config.search.placeholder || 'Search...';
        }

        form.addEventListener('submit', (e) => {
            e.preventDefault();
            const query = input.value.trim();
            if (query) {
                const searchUrl = config.search?.url || 'https://search.brave.com/search?q=';
                window.location.href = searchUrl + encodeURIComponent(query);
            }
        });
    }

    // Render link categories
    function renderLinks() {
        const container = document.getElementById('links-section');
        if (!config.links || config.links.length === 0) {
            container.style.display = 'none';
            return;
        }

        container.innerHTML = config.links.map(category => `
            <div class="link-category">
                <h3 class="category-title">${escapeHtml(category.category)}</h3>
                <ul class="link-list">
                    ${category.items.map(item => `
                        <li class="link-item">
                            <a href="${escapeHtml(item.url)}" target="_blank" rel="noopener">${escapeHtml(item.name)}</a>
                        </li>
                    `).join('')}
                </ul>
            </div>
        `).join('');
    }

    // Render services (initial state)
    function renderServices() {
        const container = document.getElementById('services-grid');
        if (!config.services || config.services.length === 0) {
            document.getElementById('services-section').style.display = 'none';
            return;
        }

        container.innerHTML = config.services.map(service => `
            <a href="${escapeHtml(service.url)}" target="_blank" rel="noopener" class="service-card" data-service="${escapeHtml(service.name)}">
                <span class="service-status unknown"></span>
                <span class="service-name">${escapeHtml(service.name)}</span>
            </a>
        `).join('');
    }

    // Load system statistics
    async function loadSystemStats() {
        try {
            const data = await loadJSON('data/system.json');
            document.getElementById('cpu-stat').textContent = data.cpu ?? '--';
            document.getElementById('ram-stat').textContent = data.ram ?? '--';
            document.getElementById('disk-stat').textContent = data.disk ?? '--';
        } catch (e) {
            // Data file might not exist yet
            console.debug('System stats not available');
        }
    }

    // Load service status
    async function loadServiceStatus() {
        try {
            const data = await loadJSON('data/services.json');
            if (data.services) {
                data.services.forEach(service => {
                    const card = document.querySelector(`[data-service="${service.name}"]`);
                    if (card) {
                        const indicator = card.querySelector('.service-status');
                        indicator.className = `service-status ${service.status}`;
                    }
                });
            }
        } catch (e) {
            // Data file might not exist yet
            console.debug('Service status not available');
        }
    }

    // HTML escape utility
    function escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    // Start the app when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();
