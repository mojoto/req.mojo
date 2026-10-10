import Link from '@docusaurus/Link';
import Layout from '@theme/Layout';
import CodeBlock from '@theme/CodeBlock';
import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';

const copy = {
  en: {
    title: 'Make HTTP requests', accent: 'the Mojo way.',
    description: 'A native synchronous HTTP client. From a simple GET to persistent sessions and streaming responses — with an API that stays out of your way.',
    start: 'Get started', api: 'Explore the API',
    caption: 'HTTP/1.1 · Verified HTTPS · Native JSON',
    tabs: ['First request', 'Persistent client', 'Streaming'],
    why: 'Everything a request needs.',
    whyText: 'A small, explicit API for the work between your application and the network.',
    features: [
      ['shield', 'Secure by default', 'Verified TLS and five-second phase timeouts. Redirects are a deliberate choice.'],
      ['arrows', 'Connections that stay useful', 'Reuse connections and keep headers, authentication, and scoped cookies in one client.'],
      ['braces', 'Your data, your format', 'Send JSON, forms, or bytes. Read responses as text, structured JSON, or raw content.'],
      ['stream', 'Room for large responses', 'Read chunks as they arrive, with incremental gzip and deflate decoding.'],
    ],
    ready: 'Your first request starts here.',
    readyText: 'Build from source, then follow the guide to link the native transport and run a Mojo program.',
    install: 'Build from source', guide: 'Read the installation guide',
  },
  'zh-Hans': {
    title: '用 Mojo，', accent: '轻松发起 HTTP 请求。',
    description: '原生同步 HTTP 客户端。从简单的 GET，到持久会话和流式响应，用清晰的 API 连接你的应用与网络。',
    start: '快速开始', api: '查看 API',
    caption: 'HTTP/1.1 · HTTPS 证书验证 · 原生 JSON',
    tabs: ['第一个请求', '持久客户端', '流式响应'],
    why: '一个请求需要的，都在这里。',
    whyText: '小而清晰的 API，让请求、响应和资源管理各就其位。',
    features: [
      ['shield', '安全的默认值', '默认验证 TLS 证书，各阶段超时为五秒，重定向由你决定是否开启。'],
      ['arrows', '让连接持续发挥作用', '复用连接，在一个客户端中管理请求头、认证和有作用域的 Cookie。'],
      ['braces', '按你的格式处理数据', '发送 JSON、表单或字节，读取文本、结构化 JSON 或原始响应内容。'],
      ['stream', '从容处理大响应', '按需分块读取响应体，增量解码 gzip 和 deflate。'],
    ],
    ready: '从第一个请求开始。',
    readyText: '从源码构建，再跟随指南链接原生传输层，运行你的 Mojo 程序。',
    install: '从源码构建', guide: '阅读安装指南',
  },
};

const examples = [
`import req


def main() raises:
    var response = req.get("https://example.com")
    response.raise_for_status()
    print(response.status_code)
    print(response.text())`,
`import req


def main() raises:
    var owner = req.Client(base_url="https://example.com/")
    with owner.context() as client:
        var response = client.get("/")
        response.raise_for_status()
        print(response.text())`,
`import req


def main() raises:
    with req.stream("GET", "https://example.com") as body:
        body.raise_for_status()
        while True:
            var chunk = body.read_chunk(65536)
            if not chunk:
                break
            print(len(chunk.value()))`,
];

const paths = {
  shield: 'M12 3 4 6v6c0 5 8 9 8 9s8-4 8-9V6l-8-3Zm-4 9 3 3 5-6',
  arrows: 'M4 8h16m-4-4 4 4-4 4M20 16H4m4-4-4 4 4 4',
  braces: 'M8 4H6v5c0 2-2 3-3 3 1 0 3 1 3 3v5h2M16 4h2v5c0 2 2 3 3 3-1 0-3 1-3 3v5h-2',
  stream: 'M4 6h16M4 12h11M4 18h6m7-4 4 4-4 4m-5-4h9',
};
function Icon({name}) {
  return <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d={paths[name]} /></svg>;
}

export default function Home() {
  const {i18n} = useDocusaurusContext();
  const text = copy[i18n.currentLocale] ?? copy.en;
  return (
    <Layout title="Req.mojo" description={text.description}>
      <main className="req-home">
        <section className="req-hero">
          <div className="container req-hero__intro">
            <h1>{text.title}<br /><span>{text.accent}</span></h1>
            <p>{text.description}</p>
            <div className="req-actions">
              <Link className="button req-primary" to="/docs/getting-started">{text.start}<span aria-hidden="true">→</span></Link>
              <Link className="req-api-link" to="/docs/api-reference">{text.api}<span aria-hidden="true">↗</span></Link>
            </div>
            <p className="req-caption">{text.caption}</p>
          </div>
          <div className="req-demo">
            <Tabs defaultValue="0" values={text.tabs.map((label, index) => ({label, value: String(index)}))}>
              {examples.map((code, index) => (
                <TabItem key={index} value={String(index)}>
                  <div className="req-editor">
                    <div className="req-editor__bar"><span className="req-dots" aria-hidden="true"><i /><i /><i /></span><span>main.mojo</span><span className="req-editor__language">Mojo</span></div>
                    <CodeBlock language="mojo" showLineNumbers>{code}</CodeBlock>
                  </div>
                </TabItem>
              ))}
            </Tabs>
          </div>
        </section>
        <section className="container req-features">
          <div className="req-section-heading"><h2>{text.why}</h2><p>{text.whyText}</p></div>
          <div className="req-feature-grid">
            {text.features.map(([icon, title, description]) => (
              <article key={title}><Icon name={icon} /><h3>{title}</h3><p>{description}</p></article>
            ))}
          </div>
        </section>
        <section className="req-get-started">
          <div className="container req-get-started__inner">
            <div><h2>{text.ready}</h2><p>{text.readyText}</p><Link to="/docs/getting-started">{text.guide} <span aria-hidden="true">→</span></Link></div>
            <CodeBlock language="bash" title={text.install}>{`git clone https://github.com/mojoto/req.mojo.git
cd req.mojo
pixi install
make build`}</CodeBlock>
          </div>
        </section>
      </main>
    </Layout>
  );
}
