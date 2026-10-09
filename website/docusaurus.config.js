// @ts-check

const {themes} = require('prism-react-renderer');

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'Req.mojo',
  tagline: 'A native synchronous HTTP client for Mojo',
  favicon: 'img/req-logo.svg',

  url: 'https://mojoto.github.io',
  baseUrl: '/req.mojo/',
  organizationName: 'mojoto',
  projectName: 'req.mojo',
  trailingSlash: false,

  onBrokenLinks: 'throw',
  markdown: {
    hooks: {
      onBrokenMarkdownLinks: 'throw',
    },
  },

  i18n: {
    defaultLocale: 'en',
    locales: ['en', 'zh-Hans'],
    localeConfigs: {
      en: {
        label: 'English',
      },
      'zh-Hans': {
        label: '简体中文',
      },
    },
  },

  presets: [
    [
      'classic',
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          sidebarPath: require.resolve('./sidebars.js'),
          editLocalizedFiles: true,
          editUrl: 'https://github.com/mojoto/req.mojo/tree/main/website/',
        },
        blog: false,
        theme: {
          customCss: require.resolve('./src/css/custom.css'),
        },
      }),
    ],
  ],

  themeConfig:
    /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
    ({
      image: 'img/req-social-card.svg',
      navbar: {
        title: 'Req.mojo',
        logo: {
          alt: 'Req request and response logo',
          src: 'img/req-logo.svg',
        },
        items: [
          {
            type: 'docSidebar',
            sidebarId: 'docsSidebar',
            position: 'left',
            label: 'Docs',
          },
          {label: 'API', to: '/docs/api-reference', position: 'left'},
          {
            type: 'localeDropdown',
            position: 'right',
          },
          {
            href: 'https://github.com/mojoto/req.mojo',
            label: 'GitHub',
            position: 'right',
          },
        ],
      },
      footer: {
        style: 'dark',
        links: [
          {
            title: 'Docs',
            items: [
              {
                label: 'Getting Started',
                to: '/docs/getting-started',
              },
              {
                label: 'API Reference',
                to: '/docs/api-reference',
              },
            ],
          },
          {
            title: 'Project',
            items: [
              {
                label: 'GitHub',
                href: 'https://github.com/mojoto/req.mojo',
              },
              {
                label: 'Releases',
                href: 'https://github.com/mojoto/req.mojo/releases',
              },
            ],
          },
        ],
        copyright: `Copyright © ${new Date().getFullYear()} Req.mojo contributors.`,
      },
      prism: {
        theme: {...themes.github, plain: {...themes.github.plain, backgroundColor: '#f6f6f7', color: '#3c3c43'}},
        darkTheme: {...themes.dracula, plain: {...themes.dracula.plain, backgroundColor: '#202127'}},
        additionalLanguages: ['python', 'bash'],
      },
    }),
};

module.exports = config;
