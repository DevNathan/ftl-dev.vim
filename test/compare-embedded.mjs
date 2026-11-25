// Run against the sibling extension's installed test dependencies and fixtures.
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import { tmpdir } from "node:os";
import { basename, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const test = fileURLToPath(new URL(".", import.meta.url));
const vsix = resolve(test, "../../vsix");
const extension = join(vsix, "extension");
const require = createRequire(join(extension, "package.json"));
const { parseGrammarTestCase } = require("vscode-tmgrammar-test/dist/unit/parsing");
const fixtures = ["html-embed.ftl", "sql-embed.ftl"].map(f => join(vsix, "tests/grammar", f));

execFileSync(process.execPath, [
  require.resolve("vscode-tmgrammar-test/dist/unit.js"),
  "-g", "syntaxes/freemarker.tmLanguage.json",
  "-g", "syntaxes/test-support/text.html.basic.tmLanguage.json",
  "-g", "syntaxes/test-support/source.sql.tmLanguage.json",
  ...fixtures,
], { cwd: extension, stdio: "inherit" });

// The asserted scope can be a parent (e.g. SQL string containing an FTL
// interpolation). Check synstack, not just the final highlight or its color.
const groups = {
  "entity.name.tag.html": ["ftlHtmlTagName"],
  "meta.tag.structure.any.html": ["ftlHtmlTag", "ftlHtmlDelimiter"],
  "meta.interpolation.freemarker": ["ftlInterpolation", "ftlDelimiter"],
  "punctuation.definition.tag.begin.freemarker": ["ftlOperator", "ftlDirKeyword"],
  "keyword.control.directive.freemarker": ["ftlDirKeyword"],
  "variable.other.freemarker": ["ftlIdentifier"],
  "keyword.other.documentation.ftldoc.freemarker": ["ftlLangTag", "ftlDocTag"],
  "comment.block.freemarker": ["ftlSqlMarker", "ftlComment", "ftlCommentSquare"],
  "string.quoted.double.freemarker": ["ftlStringD"],
  "meta.embedded.block.sql": ["ftlSqlCapture", "ftlSqlMarkedCapture"],
  "keyword.other.DML.sql": ["ftlSqlKeyword"],
  "variable.parameter.bind.sql": ["ftlSqlBind"],
  "string.quoted.single.sql": ["ftlSqlString"],
  "constant.character.escape.sql": ["ftlSqlQuoteEscape"],
  "constant.numeric.sql": ["ftlSqlNumber"],
  "string": ["ftlSqlString", "ftlStringD", "ftlStringS", "ftlRawString", "ftlHtmlString"],
};

const dir = mkdtempSync(join(tmpdir(), "ftl-embed-"));
try {
  const dump = join(dir, "groups.vim");
  writeFileSync(dump, [
    "let result = []",
    "for n in range(1, line('$'))",
    "  let cells = []",
    "  for p in range(1, strlen(getline(n)))",
    '    call add(cells, map(synstack(n, p), \'synIDattr(v:val, "name")\'))',
    "  endfor",
    "  call add(result, cells)",
    "endfor",
    "call writefile([json_encode(result)], $FTL_GROUPS)",
    "qa!",
  ].join("\n"));
  for (const fixture of fixtures) {
    const { source, assertions } = parseGrammarTestCase(readFileSync(fixture, "utf8"));
    const template = join(dir, basename(fixture));
    writeFileSync(template, source.join("\n"));
    let first;
    for (const editor of ["vim", "nvim"]) {
      const out = join(dir, editor + ".json");
      const args = editor === "vim" ? ["-N", "-es"] : ["--headless"];
      execFileSync(editor, [...args, "-n", "-i", "NONE", "-u", join(test, "vimrc"), template, "-S", dump], {
        stdio: "inherit",
        env: { ...process.env, FTL_GROUPS: out, XDG_STATE_HOME: dir },
      });
      const cells = JSON.parse(readFileSync(out, "utf8"));
      if (first) assert.deepEqual(cells, first, basename(fixture) + " editor groups differ");
      first = cells;
      let count = 0;
      for (const { sourceLineNumber: n, scopeAssertions } of assertions) {
        for (const { from, to, scopes, exclude } of scopeAssertions) {
          for (let i = from; i < to; i++) {
            const col = Buffer.byteLength(source[n].slice(0, i));
            const stack = cells[n][col];
            for (const scope of [...scopes, ...exclude]) {
              assert.ok(groups[scope], "Unmapped scope " + scope);
              assert.equal(groups[scope].some(g => stack.includes(g)), scopes.includes(scope),
                [editor, basename(fixture), n + 1, i + 1, scope, stack].join(" "));
            }
          }
          count++;
        }
      }
      console.log(editor, basename(fixture), count + " annotated spans passed");
    }
  }
} finally {
  rmSync(dir, { recursive: true, force: true });
}
