/** @type {import('@docusaurus/plugin-content-docs').SidebarsConfig} */
module.exports = {
  docsSidebar: [
    {type: 'category', label: 'Getting Started', collapsed: false,
      items: ['intro', 'getting-started']},
    {type: 'category', label: 'Core Guides', collapsed: false,
      items: ['requests', 'clients', 'streaming', 'errors']},
    {type: 'category', label: 'Reference', collapsed: false,
      items: [{type: 'category', label: 'API Reference', collapsed: true,
        items: ['api-reference', 'api/http', 'api/client', 'api/request', 'api/response', 'api/headers', 'api/query-params', 'api/url', 'api/json', 'api/auth', 'api/timeout', 'api/cookies', 'api/errors', 'api/bytes']}, 'development']},
  ],
};
