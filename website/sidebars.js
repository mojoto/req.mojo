/** @type {import('@docusaurus/plugin-content-docs').SidebarsConfig} */
module.exports = {
  docsSidebar: [
    {type: 'category', label: 'Getting Started', collapsed: false,
      items: ['intro', 'getting-started']},
    {type: 'category', label: 'Core Guides', collapsed: false,
      items: ['requests', 'clients', 'streaming', 'errors']},
    {type: 'category', label: 'Reference', collapsed: false,
      items: ['api-reference', 'development']},
  ],
};
