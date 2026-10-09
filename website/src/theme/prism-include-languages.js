import includeLanguages from '@theme-original/prism-include-languages';

export default function includeMojo(Prism) {
  includeLanguages(Prism);
  Prism.languages.mojo = Prism.languages.extend('python', {
    keyword: /\b(?:def|struct|trait|var|comptime|raises|mut|out|imm|deinit|ref|import|from|as|with|if|elif|else|while|for|in|break|continue|return|try|except|raise|not|and|or|pass|True|False|None)\b/,
  });
}
