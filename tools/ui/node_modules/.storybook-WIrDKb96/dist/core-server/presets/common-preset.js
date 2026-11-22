import CJS_COMPAT_NODE_URL_sru4mlhvd6 from 'node:url';
import CJS_COMPAT_NODE_PATH_sru4mlhvd6 from 'node:path';
import CJS_COMPAT_NODE_MODULE_sru4mlhvd6 from "node:module";

var __filename = CJS_COMPAT_NODE_URL_sru4mlhvd6.fileURLToPath(import.meta.url);
var __dirname = CJS_COMPAT_NODE_PATH_sru4mlhvd6.dirname(__filename);
var require = CJS_COMPAT_NODE_MODULE_sru4mlhvd6.createRequire(import.meta.url);

// ------------------------------------------------------------
// end of CJS compatibility banner, injected by Storybook's esbuild configuration
// ------------------------------------------------------------
import "../../_node-chunks/chunk-7FOO4VZY.js";
import {
  doesStoryFileExist,
  generateStoryFile,
  getStoryMetadata,
  getWsToken,
  parseStaticDir,
  sendTelemetryError,
  throttle
} from "../../_node-chunks/chunk-6PADJQ3N.js";
import "../../_node-chunks/chunk-Z44UHNLR.js";
import "../../_node-chunks/chunk-LFZC4GGD.js";
import "../../_node-chunks/chunk-5EBSFPNT.js";
import {
  isI18nPackage,
  isRouterPackage,
  isStateManagementPackage,
  isStylingPackage
} from "../../_node-chunks/chunk-WBQJIPO2.js";
import {
  globalSettings
} from "../../_node-chunks/chunk-KBP3PLJZ.js";
import {
  invariant
} from "../../_node-chunks/chunk-2FN7EC43.js";
import "../../_node-chunks/chunk-C2H53V4H.js";
import {
  resolvePackageDir
} from "../../_node-chunks/chunk-GMFDJH6Z.js";
import {
  isAbsolute,
  join
} from "../../_node-chunks/chunk-ZEK5SANA.js";
import {
  glob
} from "../../_node-chunks/chunk-6KXUKKG7.js";
import "../../_node-chunks/chunk-FVZGAF6J.js";
import {
  require_dist
} from "../../_node-chunks/chunk-IPFJ62CM.js";
import "../../_node-chunks/chunk-73MPA7MW.js";
import "../../_node-chunks/chunk-HULCERYQ.js";
import {
  require_picocolors
} from "../../_node-chunks/chunk-Y7LKTMXG.js";
import {
  __commonJS,
  __require,
  __toESM
} from "../../_node-chunks/chunk-ZNOZEVUY.js";

// ../../node_modules/shell-quote/quote.js
var require_quote = __commonJS({
  "../../node_modules/shell-quote/quote.js"(exports, module) {
    "use strict";
    module.exports = function(xs) {
      return xs.map(function(s) {
        return s === "" ? "''" : s && typeof s == "object" ? s.op.replace(/(.)/g, "\\$1") : /["\s\\]/.test(s) && !/'/.test(s) ? "'" + s.replace(/(['])/g, "\\$1") + "'" : /["'\s]/.test(s) ? '"' + s.replace(/(["\\$`!])/g, "\\$1") + '"' : String(s).replace(/([A-Za-z]:)?([#!"$&'()*,:;<=>?@[\\\]^`{|}])/g, "$1\\$2");
      }).join(" ");
    };
  }
});

// ../../node_modules/shell-quote/parse.js
var require_parse = __commonJS({
  "../../node_modules/shell-quote/parse.js"(exports, module) {
    "use strict";
    var CONTROL = "(?:" + [
      "\\|\\|",
      "\\&\\&",
      ";;",
      "\\|\\&",
      "\\<\\(",
      "\\<\\<\\<",
      ">>",
      ">\\&",
      "<\\&",
      "[&;()|<>]"
    ].join("|") + ")", controlRE = new RegExp("^" + CONTROL + "$"), META = "|&;()<> \\t", SINGLE_QUOTE = '"((\\\\"|[^"])*?)"', DOUBLE_QUOTE = "'((\\\\'|[^'])*?)'", hash = /^#$/, SQ = "'", DQ = '"', DS = "$", TOKEN = "", mult = 4294967296;
    for (i = 0; i < 4; i++)
      TOKEN += (mult * Math.random()).toString(16);
    var i, startsWithToken = new RegExp("^" + TOKEN);
    function matchAll(s, r) {
      for (var origIndex = r.lastIndex, matches = [], matchObj; matchObj = r.exec(s); )
        matches.push(matchObj), r.lastIndex === matchObj.index && (r.lastIndex += 1);
      return r.lastIndex = origIndex, matches;
    }
    function getVar(env2, pre, key) {
      var r = typeof env2 == "function" ? env2(key) : env2[key];
      return typeof r > "u" && key != "" ? r = "" : typeof r > "u" && (r = "$"), typeof r == "object" ? pre + TOKEN + JSON.stringify(r) + TOKEN : pre + r;
    }
    function parseInternal(string, env2, opts) {
      opts || (opts = {});
      var BS = opts.escape || "\\", BAREWORD = "(\\" + BS + `['"` + META + `]|[^\\s'"` + META + "])+", chunker = new RegExp([
        "(" + CONTROL + ")",
        // control chars
        "(" + BAREWORD + "|" + SINGLE_QUOTE + "|" + DOUBLE_QUOTE + ")+"
      ].join("|"), "g"), matches = matchAll(string, chunker);
      if (matches.length === 0)
        return [];
      env2 || (env2 = {});
      var commented = !1;
      return matches.map(function(match) {
        var s = match[0];
        if (!s || commented)
          return;
        if (controlRE.test(s))
          return { op: s };
        var quote = !1, esc = !1, out = "", isGlob = !1, i2;
        function parseEnvVar() {
          i2 += 1;
          var varend, varname, char = s.charAt(i2);
          if (char === "{") {
            if (i2 += 1, s.charAt(i2) === "}")
              throw new Error("Bad substitution: " + s.slice(i2 - 2, i2 + 1));
            if (varend = s.indexOf("}", i2), varend < 0)
              throw new Error("Bad substitution: " + s.slice(i2));
            varname = s.slice(i2, varend), i2 = varend;
          } else if (/[*@#?$!_-]/.test(char))
            varname = char, i2 += 1;
          else {
            var slicedFromI = s.slice(i2);
            varend = slicedFromI.match(/[^\w\d_]/), varend ? (varname = slicedFromI.slice(0, varend.index), i2 += varend.index - 1) : (varname = slicedFromI, i2 = s.length);
          }
          return getVar(env2, "", varname);
        }
        for (i2 = 0; i2 < s.length; i2++) {
          var c = s.charAt(i2);
          if (isGlob = isGlob || !quote && (c === "*" || c === "?"), esc)
            out += c, esc = !1;
          else if (quote)
            c === quote ? quote = !1 : quote == SQ ? out += c : c === BS ? (i2 += 1, c = s.charAt(i2), c === DQ || c === BS || c === DS ? out += c : out += BS + c) : c === DS ? out += parseEnvVar() : out += c;
          else if (c === DQ || c === SQ)
            quote = c;
          else {
            if (controlRE.test(c))
              return { op: s };
            if (hash.test(c)) {
              commented = !0;
              var commentObj = { comment: string.slice(match.index + i2 + 1) };
              return out.length ? [out, commentObj] : [commentObj];
            } else c === BS ? esc = !0 : c === DS ? out += parseEnvVar() : out += c;
          }
        }
        return isGlob ? { op: "glob", pattern: out } : out;
      }).reduce(function(prev, arg) {
        return typeof arg > "u" ? prev : prev.concat(arg);
      }, []);
    }
    module.exports = function(s, env2, opts) {
      var mapped = parseInternal(s, env2, opts);
      return typeof env2 != "function" ? mapped : mapped.reduce(function(acc, s2) {
        if (typeof s2 == "object")
          return acc.concat(s2);
        var xs = s2.split(RegExp("(" + TOKEN + ".*?" + TOKEN + ")", "g"));
        return xs.length === 1 ? acc.concat(xs[0]) : acc.concat(xs.filter(Boolean).map(function(x) {
          return startsWithToken.test(x) ? JSON.parse(x.split(TOKEN)[1]) : x;
        }));
      }, []);
    };
  }
});

// ../../node_modules/shell-quote/index.js
var require_shell_quote = __commonJS({
  "../../node_modules/shell-quote/index.js"(exports) {
    "use strict";
    exports.quote = require_quote();
    exports.parse = require_parse();
  }
});

// ../../node_modules/launch-editor/editor-info/macos.js
var require_macos = __commonJS({
  "../../node_modules/launch-editor/editor-info/macos.js"(exports, module) {
    module.exports = {
      "/Applications/Atom.app/Contents/MacOS/Atom": "atom",
      "/Applications/Atom Beta.app/Contents/MacOS/Atom Beta": "/Applications/Atom Beta.app/Contents/MacOS/Atom Beta",
      "/Applications/Brackets.app/Contents/MacOS/Brackets": "brackets",
      "/Applications/Sublime Text.app/Contents/MacOS/Sublime Text": "/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl",
      "/Applications/Sublime Text.app/Contents/MacOS/sublime_text": "/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl",
      "/Applications/Sublime Text 2.app/Contents/MacOS/Sublime Text 2": "/Applications/Sublime Text 2.app/Contents/SharedSupport/bin/subl",
      "/Applications/Sublime Text Dev.app/Contents/MacOS/Sublime Text": "/Applications/Sublime Text Dev.app/Contents/SharedSupport/bin/subl",
      "/Applications/Visual Studio Code.app/Contents/MacOS/Electron": "code",
      "/Applications/Visual Studio Code - Insiders.app/Contents/MacOS/Electron": "code-insiders",
      "/Applications/VSCodium.app/Contents/MacOS/Electron": "codium",
      "/Applications/Cursor.app/Contents/MacOS/Cursor": "cursor",
      "/Applications/Trae.app/Contents/MacOS/Electron": "trae",
      "/Applications/AppCode.app/Contents/MacOS/appcode": "/Applications/AppCode.app/Contents/MacOS/appcode",
      "/Applications/CLion.app/Contents/MacOS/clion": "/Applications/CLion.app/Contents/MacOS/clion",
      "/Applications/IntelliJ IDEA.app/Contents/MacOS/idea": "/Applications/IntelliJ IDEA.app/Contents/MacOS/idea",
      "/Applications/IntelliJ IDEA Ultimate.app/Contents/MacOS/idea": "/Applications/IntelliJ IDEA Ultimate.app/Contents/MacOS/idea",
      "/Applications/IntelliJ IDEA Community Edition.app/Contents/MacOS/idea": "/Applications/IntelliJ IDEA Community Edition.app/Contents/MacOS/idea",
      "/Applications/PhpStorm.app/Contents/MacOS/phpstorm": "/Applications/PhpStorm.app/Contents/MacOS/phpstorm",
      "/Applications/PyCharm.app/Contents/MacOS/pycharm": "/Applications/PyCharm.app/Contents/MacOS/pycharm",
      "/Applications/PyCharm CE.app/Contents/MacOS/pycharm": "/Applications/PyCharm CE.app/Contents/MacOS/pycharm",
      "/Applications/RubyMine.app/Contents/MacOS/rubymine": "/Applications/RubyMine.app/Contents/MacOS/rubymine",
      "/Applications/WebStorm.app/Contents/MacOS/webstorm": "/Applications/WebStorm.app/Contents/MacOS/webstorm",
      "/Applications/MacVim.app/Contents/MacOS/MacVim": "mvim",
      "/Applications/GoLand.app/Contents/MacOS/goland": "/Applications/GoLand.app/Contents/MacOS/goland",
      "/Applications/Rider.app/Contents/MacOS/rider": "/Applications/Rider.app/Contents/MacOS/rider",
      "/Applications/Zed.app/Contents/MacOS/zed": "zed"
    };
  }
});

// ../../node_modules/launch-editor/editor-info/linux.js
var require_linux = __commonJS({
  "../../node_modules/launch-editor/editor-info/linux.js"(exports, module) {
    module.exports = {
      atom: "atom",
      Brackets: "brackets",
      "code-insiders": "code-insiders",
      code: "code",
      vscodium: "vscodium",
      codium: "codium",
      cursor: "cursor",
      trae: "trae",
      emacs: "emacs",
      gvim: "gvim",
      idea: "idea",
      "idea.sh": "idea",
      phpstorm: "phpstorm",
      "phpstorm.sh": "phpstorm",
      pycharm: "pycharm",
      "pycharm.sh": "pycharm",
      rubymine: "rubymine",
      "rubymine.sh": "rubymine",
      sublime_text: "subl",
      vim: "vim",
      webstorm: "webstorm",
      "webstorm.sh": "webstorm",
      goland: "goland",
      "goland.sh": "goland",
      rider: "rider",
      "rider.sh": "rider",
      zed: "zed"
    };
  }
});

// ../../node_modules/launch-editor/editor-info/windows.js
var require_windows = __commonJS({
  "../../node_modules/launch-editor/editor-info/windows.js"(exports, module) {
    module.exports = [
      "Brackets.exe",
      "Code.exe",
      "Code - Insiders.exe",
      "VSCodium.exe",
      "Cursor.exe",
      "atom.exe",
      "sublime_text.exe",
      "notepad++.exe",
      "clion.exe",
      "clion64.exe",
      "idea.exe",
      "idea64.exe",
      "phpstorm.exe",
      "phpstorm64.exe",
      "pycharm.exe",
      "pycharm64.exe",
      "rubymine.exe",
      "rubymine64.exe",
      "webstorm.exe",
      "webstorm64.exe",
      "goland.exe",
      "goland64.exe",
      "rider.exe",
      "rider64.exe",
      "trae.exe"
    ];
  }
});

// ../../node_modules/launch-editor/guess.js
var require_guess = __commonJS({
  "../../node_modules/launch-editor/guess.js"(exports, module) {
    var path = __require("path"), shellQuote = require_shell_quote(), childProcess = __require("child_process"), COMMON_EDITORS_MACOS = require_macos(), COMMON_EDITORS_LINUX = require_linux(), COMMON_EDITORS_WIN = require_windows();
    module.exports = function(specifiedEditor) {
      if (specifiedEditor)
        return shellQuote.parse(specifiedEditor);
      if (process.env.LAUNCH_EDITOR)
        return [process.env.LAUNCH_EDITOR];
      if (process.versions.webcontainer)
        return [process.env.EDITOR || "code"];
      try {
        if (process.platform === "darwin") {
          let output = childProcess.execSync("ps x -o comm=", {
            stdio: ["pipe", "pipe", "ignore"]
          }).toString(), processNames = Object.keys(COMMON_EDITORS_MACOS), processList = output.split(`
`);
          for (let i = 0; i < processNames.length; i++) {
            let processName = processNames[i];
            if (processList.includes(processName))
              return [COMMON_EDITORS_MACOS[processName]];
            let processNameWithoutApplications = processName.replace("/Applications", "");
            if (output.indexOf(processNameWithoutApplications) !== -1) {
              if (processName !== COMMON_EDITORS_MACOS[processName])
                return [COMMON_EDITORS_MACOS[processName]];
              let runningProcess = processList.find((procName) => procName.endsWith(processNameWithoutApplications));
              if (runningProcess !== void 0)
                return [runningProcess];
            }
          }
        } else if (process.platform === "win32") {
          let runningProcesses = childProcess.execSync(
            'powershell -NoProfile -Command "[Console]::OutputEncoding=[Text.Encoding]::UTF8;Get-CimInstance -Query \\"select executablepath from win32_process where executablepath is not null\\" | % { $_.ExecutablePath }"',
            {
              stdio: ["pipe", "pipe", "ignore"]
            }
          ).toString().split(`\r
`);
          for (let i = 0; i < runningProcesses.length; i++) {
            let fullProcessPath = runningProcesses[i].trim(), shortProcessName = path.basename(fullProcessPath);
            if (COMMON_EDITORS_WIN.indexOf(shortProcessName) !== -1)
              return [fullProcessPath];
          }
        } else if (process.platform === "linux") {
          let output = childProcess.execSync("ps x --no-heading -o comm --sort=comm", {
            stdio: ["pipe", "pipe", "ignore"]
          }).toString(), processNames = Object.keys(COMMON_EDITORS_LINUX);
          for (let i = 0; i < processNames.length; i++) {
            let processName = processNames[i];
            if (output.indexOf(processName) !== -1)
              return [COMMON_EDITORS_LINUX[processName]];
          }
        }
      } catch {
      }
      return process.env.VISUAL ? [process.env.VISUAL] : process.env.EDITOR ? [process.env.EDITOR] : [null];
    };
  }
});

// ../../node_modules/launch-editor/get-args.js
var require_get_args = __commonJS({
  "../../node_modules/launch-editor/get-args.js"(exports, module) {
    var path = __require("path");
    module.exports = function(editor, fileName, lineNumber, columnNumber = 1) {
      switch (path.basename(editor).replace(/\.(exe|cmd|bat)$/i, "")) {
        case "atom":
        case "Atom":
        case "Atom Beta":
        case "subl":
        case "sublime":
        case "sublime_text":
        case "wstorm":
        case "charm":
        case "zed":
          return [`${fileName}:${lineNumber}:${columnNumber}`];
        case "notepad++":
          return ["-n" + lineNumber, "-c" + columnNumber, fileName];
        case "vim":
        case "mvim":
          return [`+call cursor(${lineNumber}, ${columnNumber})`, fileName];
        case "joe":
        case "gvim":
          return [`+${lineNumber}`, fileName];
        case "emacs":
        case "emacsclient":
          return [`+${lineNumber}:${columnNumber}`, fileName];
        case "rmate":
        case "mate":
        case "mine":
          return ["--line", lineNumber, fileName];
        case "code":
        case "Code":
        case "code-insiders":
        case "Code - Insiders":
        case "codium":
        case "trae":
        case "cursor":
        case "vscodium":
        case "VSCodium":
          return ["-r", "-g", `${fileName}:${lineNumber}:${columnNumber}`];
        case "appcode":
        case "clion":
        case "clion64":
        case "idea":
        case "idea64":
        case "phpstorm":
        case "phpstorm64":
        case "pycharm":
        case "pycharm64":
        case "rubymine":
        case "rubymine64":
        case "webstorm":
        case "webstorm64":
        case "goland":
        case "goland64":
        case "rider":
        case "rider64":
          return ["--line", lineNumber, "--column", columnNumber, fileName];
      }
      return process.env.LAUNCH_EDITOR ? [fileName, lineNumber, columnNumber] : [fileName];
    };
  }
});

// ../../node_modules/launch-editor/index.js
var require_launch_editor = __commonJS({
  "../../node_modules/launch-editor/index.js"(exports, module) {
    var fs = __require("fs"), os = __require("os"), path = __require("path"), colors = require_picocolors(), childProcess = __require("child_process"), guessEditor = require_guess(), getArgumentsForPosition = require_get_args();
    function wrapErrorCallback(cb) {
      return (fileName, errorMessage) => {
        console.log(), console.log(
          colors.red("Could not open " + path.basename(fileName) + " in the editor.")
        ), errorMessage && (errorMessage[errorMessage.length - 1] !== "." && (errorMessage += "."), console.log(
          colors.red("The editor process exited with an error: " + errorMessage)
        )), console.log(), cb && cb(fileName, errorMessage);
      };
    }
    function isTerminalEditor(editor) {
      switch (editor) {
        case "vim":
        case "emacs":
        case "nano":
          return !0;
      }
      return !1;
    }
    var positionRE = /:(\d+)(:(\d+))?$/;
    function parseFile(file) {
      file.startsWith("file://") && (file = __require("url").fileURLToPath(file));
      let fileName = file.replace(positionRE, ""), match = file.match(positionRE), lineNumber = match && match[1], columnNumber = match && match[3];
      return {
        fileName,
        lineNumber,
        columnNumber
      };
    }
    var _childProcess = null;
    function launchEditor(file, specifiedEditor, onErrorCallback) {
      let parsed = parseFile(file), { fileName } = parsed, { lineNumber, columnNumber } = parsed;
      if (!fs.existsSync(fileName))
        return;
      typeof specifiedEditor == "function" && (onErrorCallback = specifiedEditor, specifiedEditor = void 0), onErrorCallback = wrapErrorCallback(onErrorCallback);
      let [editor, ...args] = guessEditor(specifiedEditor);
      if (!editor) {
        onErrorCallback(fileName, null);
        return;
      }
      if (process.platform === "linux" && fileName.startsWith("/mnt/") && /Microsoft/i.test(os.release()) && (fileName = path.relative("", fileName)), lineNumber) {
        let extraArgs = getArgumentsForPosition(editor, fileName, lineNumber, columnNumber);
        args.push.apply(args, extraArgs);
      } else
        args.push(fileName);
      if (_childProcess && isTerminalEditor(editor) && _childProcess.kill("SIGKILL"), process.platform === "win32") {
        let escapeCmdArgs2 = function(cmdArgs) {
          return cmdArgs.replace(/([&|<>,;=^])/g, "^$1");
        }, doubleQuoteIfNeeded2 = function(str) {
          return str.includes("^") ? `^"${str}^"` : str.includes(" ") ? `"${str}"` : str;
        };
        var escapeCmdArgs = escapeCmdArgs2, doubleQuoteIfNeeded = doubleQuoteIfNeeded2;
        let launchCommand = [editor, ...args.map(escapeCmdArgs2)].map(doubleQuoteIfNeeded2).join(" ");
        _childProcess = childProcess.exec(launchCommand, {
          stdio: "inherit",
          shell: !0
        });
      } else
        _childProcess = childProcess.spawn(editor, args, { stdio: "inherit" });
      _childProcess.on("exit", function(errorCode) {
        _childProcess = null, errorCode && onErrorCallback(fileName, "(code " + errorCode + ")");
      }), _childProcess.on("error", function(error) {
        let { code, message } = error;
        code === "ENOENT" && (message = `${message} ('${editor}' command does not exist in 'PATH')`), onErrorCallback(fileName, message);
      });
    }
    module.exports = launchEditor;
  }
});

// src/core-server/presets/common-preset.ts
import { existsSync as existsSync2 } from "node:fs";
import { readFile as readFile4 } from "node:fs/promises";
import { normalizeStories, optionalEnvToBoolean } from "storybook/internal/common";
import {
  JsPackageManagerFactory,
  getDirectoryFromWorkingDir,
  getPreviewBodyTemplate,
  getPreviewHeadTemplate,
  loadEnvs,
  removeAddon as removeAddonBase
} from "storybook/internal/common";
import { StoryIndexGenerator } from "storybook/internal/core-server";
import { loadCsf } from "storybook/internal/csf-tools";
import { logger as logger4 } from "storybook/internal/node-logger";
import { telemetry as telemetry9 } from "storybook/internal/telemetry";
var import_ts_dedent = __toESM(require_dist(), 1);

// src/core-server/server-channel/create-new-story-channel.ts
import {
  CREATE_NEW_STORYFILE_REQUEST,
  CREATE_NEW_STORYFILE_RESPONSE
} from "storybook/internal/core-events";
import { telemetry } from "storybook/internal/telemetry";
function initCreateNewStoryChannel(channel, options, coreOptions) {
  return channel.on(
    CREATE_NEW_STORYFILE_REQUEST,
    async (data) => {
      let result = await generateStoryFile(data.payload, options);
      result.success ? (channel.emit(CREATE_NEW_STORYFILE_RESPONSE, {
        success: !0,
        id: data.id,
        payload: {
          storyId: result.storyId,
          storyFilePath: result.storyFilePath,
          exportedStoryName: result.exportedStoryName
        },
        error: null
      }), coreOptions.disableTelemetry || telemetry("create-new-story-file", {
        success: !0
      })) : (channel.emit(CREATE_NEW_STORYFILE_RESPONSE, {
        success: !1,
        id: data.id,
        payload: result.errorType === "STORY_FILE_EXISTS" ? {
          type: "STORY_FILE_EXISTS",
          kind: result.kind
        } : void 0,
        error: result.error || "Unknown error occurred"
      }), coreOptions.disableTelemetry || await telemetry("create-new-story-file", {
        success: !1,
        error: result.errorType || result.error
      }));
    }
  ), channel;
}

// src/core-server/server-channel/file-search-channel.ts
import { readFile } from "node:fs/promises";
import { dirname, join as join2 } from "node:path";
import { extractRenderer, getFrameworkName, getProjectRoot } from "storybook/internal/common";
import {
  FILE_COMPONENT_SEARCH_REQUEST,
  FILE_COMPONENT_SEARCH_RESPONSE
} from "storybook/internal/core-events";
import { telemetry as telemetry2 } from "storybook/internal/telemetry";

// src/core-server/utils/parser/generic-parser.ts
import { parser, types as t } from "storybook/internal/babel";
var GenericParser = class {
  /**
   * Parse the content of a file and return the exports
   *
   * @param content The content of the file
   * @returns The exports of the file
   */
  async parse(content) {
    let ast = parser.parse(content, {
      allowImportExportEverywhere: !0,
      allowAwaitOutsideFunction: !0,
      allowNewTargetOutsideFunction: !0,
      allowReturnOutsideFunction: !0,
      allowUndeclaredExports: !0,
      plugins: [
        // Language features
        "typescript",
        "jsx",
        // Latest ECMAScript features
        "asyncGenerators",
        "bigInt",
        "classProperties",
        "classPrivateProperties",
        "classPrivateMethods",
        "classStaticBlock",
        "dynamicImport",
        "exportNamespaceFrom",
        "logicalAssignment",
        "moduleStringNames",
        "nullishCoalescingOperator",
        "numericSeparator",
        "objectRestSpread",
        "optionalCatchBinding",
        "optionalChaining",
        "privateIn",
        "regexpUnicodeSets",
        "topLevelAwait",
        // ECMAScript proposals
        "asyncDoExpressions",
        "decimal",
        "decorators",
        "decoratorAutoAccessors",
        "deferredImportEvaluation",
        "destructuringPrivate",
        "doExpressions",
        "explicitResourceManagement",
        "exportDefaultFrom",
        "functionBind",
        "functionSent",
        "importAttributes",
        "importReflection",
        "moduleBlocks",
        "partialApplication",
        "recordAndTuple",
        "sourcePhaseImports",
        "throwExpressions"
      ]
    }), exports = [];
    return ast.program.body.forEach(function(node) {
      t.isExportNamedDeclaration(node) ? (t.isFunctionDeclaration(node.declaration) && t.isIdentifier(node.declaration.id) && exports.push({
        name: node.declaration.id.name,
        default: !1
      }), t.isClassDeclaration(node.declaration) && t.isIdentifier(node.declaration.id) && exports.push({
        name: node.declaration.id.name,
        default: !1
      }), node.declaration === null && node.specifiers.length > 0 && node.specifiers.forEach((specifier) => {
        t.isExportSpecifier(specifier) && t.isIdentifier(specifier.exported) && exports.push({
          name: specifier.exported.name,
          default: !1
        });
      }), t.isVariableDeclaration(node.declaration) && node.declaration.declarations.forEach((declaration) => {
        t.isVariableDeclarator(declaration) && t.isIdentifier(declaration.id) && exports.push({
          name: declaration.id.name,
          default: !1
        });
      })) : t.isExportDefaultDeclaration(node) && exports.push({
        name: "default",
        default: !0
      });
    }), { exports };
  }
};

// src/core-server/utils/parser/index.ts
function getParser(renderer) {
  return new GenericParser();
}

// src/core-server/utils/search-files.ts
var FILE_EXTENSIONS = ["js", "mjs", "cjs", "jsx", "mts", "ts", "tsx", "cts"], IGNORED_FILES = [
  "**/node_modules/**",
  "**/*.spec.*",
  "**/*.test.*",
  "**/*.stories.*",
  "**/storybook-static/**"
];
async function searchFiles({
  searchQuery,
  cwd,
  ignoredFiles = IGNORED_FILES,
  fileExtensions = FILE_EXTENSIONS
}) {
  let { globby, isDynamicPattern } = await import("../../_node-chunks/globby-2JQDE3NB.js"), hasSearchSpecialGlobChars = isDynamicPattern(searchQuery, { cwd }), searchQueryHasExtension = /(\.[a-z]+)$/i.test(searchQuery), fileExtensionsPattern = `{${fileExtensions.join(",")}}`, globbedSearchQuery = hasSearchSpecialGlobChars ? searchQuery : searchQueryHasExtension ? [`**/*${searchQuery}*`, `**/*${searchQuery}*/**`] : [
    `**/*${searchQuery}*.${fileExtensionsPattern}`,
    `**/*${searchQuery}*/**/*.${fileExtensionsPattern}`
  ];
  return (await globby(globbedSearchQuery, {
    ignore: ignoredFiles,
    gitignore: !0,
    caseSensitiveMatch: !1,
    cwd,
    objectMode: !0
  })).map((entry) => entry.path).filter((entry) => fileExtensions.some((ext) => entry.endsWith(`.${ext}`)));
}

// src/core-server/server-channel/file-search-channel.ts
async function initFileSearchChannel(channel, options, coreOptions) {
  return channel.on(
    FILE_COMPONENT_SEARCH_REQUEST,
    async (data) => {
      let searchQuery = data.id;
      try {
        if (!searchQuery)
          return;
        let frameworkName = await getFrameworkName(options), rendererName = await extractRenderer(frameworkName), entries = (await searchFiles({
          searchQuery,
          cwd: getProjectRoot()
        })).map(async (file) => {
          let parser3 = getParser(rendererName);
          try {
            let content = await readFile(join2(getProjectRoot(), file), "utf-8"), { storyFileName } = getStoryMetadata(join2(getProjectRoot(), file)), dir = dirname(file), storyFileExists = doesStoryFileExist(join2(getProjectRoot(), dir), storyFileName), info = await parser3.parse(content);
            return {
              filepath: file,
              exportedComponents: info.exports,
              storyFileExists
            };
          } catch (e) {
            return coreOptions.disableTelemetry || telemetry2("create-new-story-file-search", {
              success: !1,
              error: `Could not parse file: ${e}`
            }), {
              filepath: file,
              storyFileExists: !1,
              exportedComponents: null
            };
          }
        });
        coreOptions.disableTelemetry || telemetry2("create-new-story-file-search", {
          success: !0,
          payload: {
            fileCount: entries.length
          }
        }), channel.emit(FILE_COMPONENT_SEARCH_RESPONSE, {
          success: !0,
          id: searchQuery,
          payload: {
            files: await Promise.all(entries)
          },
          error: null
        });
      } catch (e) {
        channel.emit(FILE_COMPONENT_SEARCH_RESPONSE, {
          success: !1,
          id: searchQuery ?? "",
          error: `An error occurred while searching for components in the project.
${e?.message}`
        }), coreOptions.disableTelemetry || telemetry2("create-new-story-file-search", {
          success: !1,
          error: `An error occurred while searching for components: ${e}`
        });
      }
    }
  ), channel;
}

// src/core-server/server-channel/ghost-stories-channel.ts
import { GHOST_STORIES_REQUEST, GHOST_STORIES_RESPONSE } from "storybook/internal/core-events";
import {
  getLastEvents,
  getSessionId,
  getStorybookMetadata,
  telemetry as telemetry3
} from "storybook/internal/telemetry";

// src/core-server/utils/ghost-stories/get-candidates.ts
import { readFile as readFile2 } from "node:fs/promises";
import { babelParse, traverse } from "storybook/internal/babel";

// src/core-server/utils/ghost-stories/component-analyzer.ts
var COMPLEXITY_CONFIG = {
  /** Weight applied to non-empty lines */
  locWeight: 1,
  /** Imports can be cheap, so they get a lower weight */
  importWeight: 0.5,
  /**
   * Defines what raw complexity value should map to the upper bound of a "simple" file For instance
   * 30 LOC + 4 imports = 32. This would result in a score of 0.3
   */
  simpleBaseline: 32,
  simpleScore: 0.3
}, getComponentComplexity = (fileContent) => {
  let lines = fileContent.split(`
`), nonEmptyLines = lines.filter((line) => line.trim() !== "").length, importCount = lines.filter((line) => line.trim().startsWith("import")).length, normalizedScore = (nonEmptyLines * COMPLEXITY_CONFIG.locWeight + importCount * COMPLEXITY_CONFIG.importWeight) / (COMPLEXITY_CONFIG.simpleBaseline / COMPLEXITY_CONFIG.simpleScore);
  return Math.min(normalizedScore, 1);
};

// src/core-server/utils/ghost-stories/get-candidates.ts
function isValidCandidate(source) {
  let ast = babelParse(source), hasJSX = !1, hasExport = !1;
  return traverse(ast, {
    JSXElement(path) {
      hasJSX = !0, hasExport && path.stop();
    },
    JSXFragment(path) {
      hasJSX = !0, hasExport && path.stop();
    },
    ExportNamedDeclaration(path) {
      hasExport = !0, hasJSX && path.stop();
    },
    ExportDefaultDeclaration(path) {
      hasExport = !0, hasJSX && path.stop();
    },
    ExportAllDeclaration(path) {
      hasExport = !0, hasJSX && path.stop();
    }
  }), hasJSX && hasExport;
}
async function getCandidatesForStorybook(files, sampleCount) {
  let simpleCandidates = [], analyzedCandidates = [];
  for (let file of files) {
    let source;
    try {
      if (source = await readFile2(file, "utf-8"), !isValidCandidate(source))
        continue;
    } catch {
      continue;
    }
    let complexity = getComponentComplexity(source);
    if (analyzedCandidates.push({ file, complexity }), complexity < 0.3 && (simpleCandidates.push({ file, complexity }), simpleCandidates.length >= sampleCount))
      break;
  }
  let selectedCandidates = [];
  simpleCandidates.length >= sampleCount ? selectedCandidates = simpleCandidates.sort((a, b) => a.complexity - b.complexity).slice(0, sampleCount) : selectedCandidates = analyzedCandidates.sort((a, b) => a.complexity - b.complexity).slice(0, sampleCount);
  let avgComplexity = selectedCandidates.length > 0 ? Number(
    (selectedCandidates.reduce((acc, curr) => acc + curr.complexity, 0) / selectedCandidates.length).toFixed(2)
  ) : 0;
  return {
    candidates: selectedCandidates.map(({ file }) => file),
    analyzedCount: analyzedCandidates.length,
    avgComplexity
  };
}
async function getComponentCandidates({
  sampleSize = 20,
  globPattern = "**/*.{tsx,jsx}"
} = {}) {
  let globMatchCount = 0;
  try {
    let files = [];
    if (files = await glob(globPattern, {
      cwd: process.cwd(),
      absolute: !0,
      ignore: [
        "**/node_modules/**",
        "**/.git/**",
        "**/dist/**",
        "**/__mocks__/**",
        "**/build/**",
        "**/storybook-static/**",
        "**/*.test.*",
        "**/*.d.*",
        "**/*.config.*",
        "**/*.spec.*",
        "**/*.stories.*",
        // skip example story files that come from the CLI
        "**/stories/{Button,Header,Page}.*",
        "**/stories/{button,header,page}.*"
      ]
    }), globMatchCount = files.length, globMatchCount === 0)
      return {
        candidates: [],
        globMatchCount
      };
    let { analyzedCount, avgComplexity, candidates } = await getCandidatesForStorybook(
      files,
      sampleSize
    );
    return {
      analyzedCount,
      avgComplexity,
      candidates,
      globMatchCount
    };
  } catch {
    return {
      candidates: [],
      error: "Failed to find candidates",
      globMatchCount
    };
  }
}

// src/core-server/utils/ghost-stories/run-story-tests.ts
import { existsSync } from "node:fs";
import { mkdir, readFile as readFile3 } from "node:fs/promises";
import { executeCommand, resolvePathInStorybookCache } from "storybook/internal/common";

// src/shared/utils/categorize-render-errors.ts
var ERROR_CATEGORIES = {
  MISSING_PROVIDER: "MISSING_PROVIDER",
  MISSING_STATE_PROVIDER: "MISSING_STATE_PROVIDER",
  MISSING_ROUTER_PROVIDER: "MISSING_ROUTER_PROVIDER",
  MISSING_THEME_PROVIDER: "MISSING_THEME_PROVIDER",
  MISSING_TRANSLATION_PROVIDER: "MISSING_TRANSLATION_PROVIDER",
  MISSING_PORTAL_ROOT: "MISSING_PORTAL_ROOT",
  HOOK_USAGE_ERROR: "HOOK_USAGE_ERROR",
  MODULE_IMPORT_ERROR: "MODULE_IMPORT_ERROR",
  COMPONENT_RENDER_ERROR: "COMPONENT_RENDER_ERROR",
  SERVER_COMPONENTS_ERROR: "SERVER_COMPONENTS_ERROR",
  UNKNOWN_ERROR: "UNKNOWN_ERROR",
  // Vite related errors
  DYNAMIC_MODULE_IMPORT_ERROR: "DYNAMIC_MODULE_IMPORT_ERROR",
  // Vitest test run related errors
  TEST_FILE_IMPORT_ERROR: "TEST_FILE_IMPORT_ERROR"
};
function buildErrorContext(message, stack) {
  let normalizedMessage = message.toLowerCase(), normalizedStack = (stack ?? "").toLowerCase(), stackDeps = /* @__PURE__ */ new Set(), stackLines = normalizedStack.split(`
`).filter(Boolean);
  for (let line of stackLines) {
    let depMatch = line.match(/\/deps\/([^:]+)\.js/);
    depMatch && stackDeps.add(depMatch[1]);
  }
  return {
    message,
    stack,
    normalizedMessage,
    normalizedStack,
    stackDeps
  };
}
var CATEGORIZATION_RULES = [
  {
    category: ERROR_CATEGORIES.MODULE_IMPORT_ERROR,
    priority: 100,
    match: (ctx) => ctx.normalizedMessage.includes("cannot find module") || ctx.normalizedMessage.includes("module not found") || ctx.normalizedMessage.includes("cannot resolve module")
  },
  {
    category: ERROR_CATEGORIES.TEST_FILE_IMPORT_ERROR,
    priority: 95,
    match: (ctx) => ctx.normalizedMessage.includes("failed to import test file")
  },
  {
    category: ERROR_CATEGORIES.DYNAMIC_MODULE_IMPORT_ERROR,
    priority: 95,
    match: (ctx) => ctx.normalizedMessage.includes("failed to fetch dynamically imported module")
  },
  {
    category: ERROR_CATEGORIES.HOOK_USAGE_ERROR,
    priority: 90,
    match: (ctx) => ctx.normalizedMessage.includes("invalid hook call") || ctx.normalizedMessage.includes("rendered more hooks than") || ctx.normalizedMessage.includes("hooks can only be called")
  },
  {
    category: ERROR_CATEGORIES.MISSING_STATE_PROVIDER,
    priority: 85,
    match: (ctx) => Array.from(ctx.stackDeps).some(isStateManagementPackage) && (ctx.normalizedMessage.includes("context") || ctx.normalizedMessage.includes("undefined") || ctx.normalizedMessage.includes("null"))
  },
  {
    category: ERROR_CATEGORIES.MISSING_ROUTER_PROVIDER,
    priority: 85,
    match: (ctx) => Array.from(ctx.stackDeps).some(isRouterPackage) || ctx.normalizedMessage.includes("usenavigate") || ctx.normalizedMessage.includes("router")
  },
  {
    category: ERROR_CATEGORIES.SERVER_COMPONENTS_ERROR,
    priority: 85,
    match: (ctx) => ctx.normalizedMessage.includes("server components") || ctx.normalizedMessage.includes("use client") || ctx.normalizedMessage.includes("async/await") && ctx.normalizedMessage.includes("not supported")
  },
  {
    category: ERROR_CATEGORIES.MISSING_THEME_PROVIDER,
    priority: 80,
    match: (ctx) => Array.from(ctx.stackDeps).some(isStylingPackage) && (ctx.normalizedMessage.includes("theme") || ctx.normalizedMessage.includes("undefined")) || ctx.normalizedMessage.includes("usetheme") || ctx.normalizedMessage.includes("theme") && ctx.normalizedMessage.includes("provider")
  },
  {
    category: ERROR_CATEGORIES.MISSING_TRANSLATION_PROVIDER,
    priority: 80,
    match: (ctx) => Array.from(ctx.stackDeps).some(isI18nPackage) || ctx.normalizedMessage.includes("i18n") || ctx.normalizedMessage.includes("translation") || ctx.normalizedMessage.includes("locale")
  },
  {
    category: ERROR_CATEGORIES.MISSING_PORTAL_ROOT,
    priority: 70,
    match: (ctx) => ctx.normalizedMessage.includes("portal") && (ctx.normalizedMessage.includes("container") || ctx.normalizedMessage.includes("root")) && (ctx.normalizedMessage.includes("null") || ctx.normalizedMessage.includes("not found"))
  },
  {
    category: ERROR_CATEGORIES.MISSING_PROVIDER,
    priority: 60,
    match: (ctx) => ctx.normalizedMessage.includes("use") && ctx.normalizedMessage.includes("provider") || ctx.normalizedMessage.includes("<provider>") || (ctx.normalizedMessage.includes("could not find") || ctx.normalizedMessage.includes("missing")) && ctx.normalizedMessage.includes("context") || ctx.normalizedMessage.includes("usecontext") && (ctx.normalizedMessage.includes("null") || ctx.normalizedMessage.includes("undefined"))
  },
  {
    category: ERROR_CATEGORIES.COMPONENT_RENDER_ERROR,
    priority: 10,
    match: (ctx) => ctx.normalizedMessage.includes("cannot read") || ctx.normalizedMessage.includes("undefined is not a function") || ctx.normalizedMessage.includes("render")
  }
], RULES = CATEGORIZATION_RULES.sort((a, b) => b.priority - a.priority);
function categorizeError(message, stack) {
  let ctx = buildErrorContext(message, stack), rule = RULES.find((r) => r.match(ctx));
  if (!rule)
    return { category: ERROR_CATEGORIES.UNKNOWN_ERROR, matchedDependencies: [] };
  let matchedDependencies = getMatchedDependencies(rule.category, ctx);
  return { category: rule.category, matchedDependencies };
}
function getMatchedDependencies(category, ctx) {
  switch (category) {
    case ERROR_CATEGORIES.MISSING_STATE_PROVIDER:
      return Array.from(ctx.stackDeps).filter(isStateManagementPackage);
    case ERROR_CATEGORIES.MISSING_ROUTER_PROVIDER:
      return Array.from(ctx.stackDeps).filter(isRouterPackage);
    case ERROR_CATEGORIES.MISSING_THEME_PROVIDER:
      return Array.from(ctx.stackDeps).filter(isStylingPackage);
    case ERROR_CATEGORIES.MISSING_TRANSLATION_PROVIDER:
      return Array.from(ctx.stackDeps).filter(isI18nPackage);
    default:
      return [];
  }
}

// src/core-server/utils/ghost-stories/parse-vitest-report.ts
function extractCategorizedErrors(testResults) {
  let failed = testResults.filter((r) => r.status === "FAIL" && r.error), map = /* @__PURE__ */ new Map(), uniqueErrorMessages = /* @__PURE__ */ new Set();
  for (let r of failed) {
    let { category, matchedDependencies } = categorizeError(r.error, r.stack);
    map.has(category) || map.set(category, { count: 0, uniqueErrors: /* @__PURE__ */ new Set(), matchedDependencies: /* @__PURE__ */ new Set() });
    let data = map.get(category);
    data.count++, matchedDependencies.forEach((dep) => data.matchedDependencies.add(dep)), uniqueErrorMessages.add(r.error), data.uniqueErrors.add(r.error);
  }
  let categorizedErrors = Array.from(map.entries()).reduce(
    (acc, [category, data]) => (acc[category] = {
      uniqueCount: data.uniqueErrors.size,
      count: data.count,
      matchedDependencies: Array.from(data.matchedDependencies).sort()
    }, acc),
    {}
  );
  return {
    totalErrors: failed.length,
    uniqueErrorCount: uniqueErrorMessages.size,
    categorizedErrors
  };
}
function parseVitestResults(report) {
  let storyTestResults = [], passedButEmptyRender = 0;
  for (let testSuite of report.testResults)
    for (let assertion of testSuite.assertionResults) {
      let storyId = assertion.meta?.storyId || assertion.fullName, status = assertion.status === "passed" ? "PASS" : assertion.status === "failed" ? "FAIL" : "PENDING", hasEmptyRender = assertion.meta?.reports?.some(
        (report2) => report2.type === "render-analysis" && report2.result?.emptyRender === !0
      );
      status === "PASS" && hasEmptyRender && passedButEmptyRender++;
      let error, stack;
      assertion.failureMessages && assertion.failureMessages.length > 0 && (stack = assertion.failureMessages[0], error = stack?.split(`
`)[0]), storyTestResults.push({
        storyId,
        status,
        error,
        stack
      });
    }
  let total = report.numTotalTests, passed = report.numPassedTests, successRate = total > 0 ? parseFloat((passed / total).toFixed(2)) : 0, successRateWithoutEmptyRender = total > 0 ? parseFloat(((passed - passedButEmptyRender) / total).toFixed(2)) : 0, errorClassification = extractCategorizedErrors(storyTestResults), categorizedErrors = errorClassification.categorizedErrors;
  return {
    summary: {
      total,
      passed,
      passedButEmptyRender,
      successRate,
      successRateWithoutEmptyRender,
      uniqueErrorCount: errorClassification.uniqueErrorCount,
      categorizedErrors
    }
  };
}

// src/core-server/utils/ghost-stories/run-story-tests.ts
async function runStoryTests(componentFilePaths) {
  try {
    let cacheDir = resolvePathInStorybookCache("ghost-stories-tests");
    await mkdir(cacheDir, { recursive: !0 });
    let timestamp = Date.now(), outputFile = join(cacheDir, `test-results-${timestamp}.json`), startTime = Date.now(), testFailureMessage;
    try {
      await executeCommand({
        command: "npx",
        args: [
          "vitest",
          "run",
          "--reporter=json",
          "--testTimeout=1000",
          `--outputFile=${outputFile}`,
          ...componentFilePaths
        ],
        stdio: "pipe",
        env: {
          STORYBOOK_COMPONENT_PATHS: componentFilePaths.join(";")
        }
      });
    } catch (error) {
      let errorMessage = (error.stderr || String(error) || "").toLowerCase();
      errorMessage.includes("browsertype.launch") ? testFailureMessage = "Playwright is not installed" : errorMessage.includes("startup error") ? testFailureMessage = "Startup Error" : errorMessage.includes("no tests found") ? testFailureMessage = "No tests found" : errorMessage.includes("test timeout") ? testFailureMessage = "Test timeout" : errorMessage.includes("react-native-web") ? testFailureMessage = "React Native Web error" : errorMessage.includes("unhandled rejection") && (testFailureMessage = "Unhandled Rejection");
    }
    let duration = Date.now() - startTime;
    if (testFailureMessage)
      return {
        duration,
        runError: testFailureMessage
      };
    if (!existsSync(outputFile))
      return {
        duration,
        runError: "JSON report not found"
      };
    let vitestReport;
    try {
      let resultsJson = await readFile3(outputFile, "utf8");
      vitestReport = JSON.parse(resultsJson);
    } catch {
      return {
        duration,
        runError: "Failed to read or parse JSON report"
      };
    }
    return !vitestReport.testResults || vitestReport.testResults.length === 0 ? {
      duration,
      runError: "No tests found"
    } : { ...parseVitestResults(vitestReport), duration };
  } catch {
    return {
      runError: "Uncaught error running story tests",
      duration: 0
    };
  }
}

// src/core-server/server-channel/ghost-stories-channel.ts
function initGhostStoriesChannel(channel, options, coreOptions) {
  return coreOptions.disableTelemetry || channel.on(GHOST_STORIES_REQUEST, async () => {
    let stats = {};
    try {
      let ghostRunStart = Date.now(), lastEvents = await getLastEvents(), lastInit = lastEvents?.init;
      if (!lastEvents || !lastInit)
        return;
      let sessionId = await getSessionId();
      if (lastEvents["ghost-stories"] || lastInit.body?.sessionId && lastInit.body.sessionId !== sessionId)
        return;
      let metadata = await getStorybookMetadata(options.configDir), isReactStorybook = metadata?.renderer?.includes("@storybook/react"), hasVitestAddon = !!metadata?.addons && Object.keys(metadata.addons).some(
        (addonKey) => addonKey.includes("@storybook/addon-vitest")
      );
      if (!isReactStorybook || !hasVitestAddon)
        return;
      let candidateAnalysisStart = Date.now(), candidatesResult = await getComponentCandidates();
      if (stats.candidateAnalysisDuration = Date.now() - candidateAnalysisStart, stats.globMatchCount = candidatesResult.globMatchCount, stats.analyzedCount = candidatesResult.analyzedCount ?? 0, stats.avgComplexity = candidatesResult.avgComplexity ?? 0, stats.candidateCount = candidatesResult.candidates.length, candidatesResult.error) {
        stats.totalRunDuration = Date.now() - ghostRunStart, telemetry3("ghost-stories", {
          stats,
          runError: candidatesResult.error
        });
        return;
      }
      if (candidatesResult.candidates.length === 0) {
        stats.totalRunDuration = Date.now() - ghostRunStart, telemetry3("ghost-stories", {
          stats,
          runError: "No candidates found"
        });
        return;
      }
      let testRunResult = await runStoryTests(candidatesResult.candidates);
      if (stats.totalRunDuration = Date.now() - ghostRunStart, stats.testRunDuration = testRunResult.duration, testRunResult.runError) {
        telemetry3("ghost-stories", {
          stats,
          runError: testRunResult.runError
        });
        return;
      }
      telemetry3("ghost-stories", {
        stats,
        results: testRunResult.summary
      });
    } catch {
      telemetry3("ghost-stories", {
        stats,
        runError: "Unknown error during ghost run"
      });
    } finally {
      channel.emit(GHOST_STORIES_RESPONSE);
    }
  }), channel;
}

// src/core-server/server-channel/open-in-editor-channel.ts
var import_launch_editor = __toESM(require_launch_editor(), 1);
import { OPEN_IN_EDITOR_REQUEST, OPEN_IN_EDITOR_RESPONSE } from "storybook/internal/core-events";
import { telemetry as telemetry4 } from "storybook/internal/telemetry";
async function initOpenInEditorChannel(channel, _options, coreOptions) {
  return channel.on(OPEN_IN_EDITOR_REQUEST, async (payload) => {
    let sendTelemetry = (data) => {
      coreOptions.disableTelemetry || telemetry4("open-in-editor", data);
    };
    try {
      let { file: targetFile, line, column } = payload;
      if (!targetFile)
        throw new Error("No file was provided to open");
      let location = typeof line == "number" ? `${targetFile}:${line}${typeof column == "number" ? `:${column}` : ""}` : targetFile;
      await new Promise((resolve, reject) => {
        (0, import_launch_editor.default)(location, void 0, (_fileName, errorMessage) => {
          errorMessage ? reject(new Error(errorMessage)) : resolve();
        });
      }), channel.emit(OPEN_IN_EDITOR_RESPONSE, {
        file: targetFile,
        line,
        column,
        error: null
      }), sendTelemetry({ success: !0 });
    } catch (e) {
      let error = e?.message || "Failed to open in editor";
      channel.emit(OPEN_IN_EDITOR_RESPONSE, {
        error,
        ...payload
      }), sendTelemetry({ success: !1, error });
    }
  }), channel;
}

// src/core-server/server-channel/telemetry-channel.ts
import {
  PREVIEW_INITIALIZED,
  SHARE_ISOLATE_MODE,
  SHARE_POPOVER_OPENED,
  SHARE_STORY_LINK
} from "storybook/internal/core-events";
import { telemetry as telemetry5 } from "storybook/internal/telemetry";
import { getLastEvents as getLastEvents2 } from "storybook/internal/telemetry";
import { getSessionId as getSessionId2 } from "storybook/internal/telemetry";
var makePayload = (userAgent, lastInit, sessionId) => {
  let payload = {
    userAgent,
    isNewUser: !1,
    timeSinceInit: void 0
  };
  return sessionId && lastInit?.body?.sessionId === sessionId && (payload.timeSinceInit = Date.now() - lastInit.timestamp, payload.isNewUser = !!lastInit.body.payload.newUser), payload;
};
function initTelemetryChannel(channel, options) {
  options.disableTelemetry || (channel.on(PREVIEW_INITIALIZED, async ({ userAgent }) => {
    try {
      let sessionId = await getSessionId2(), lastEvents = await getLastEvents2(), lastInit = lastEvents.init;
      if (!lastEvents["preview-first-load"]) {
        let payload = makePayload(userAgent, lastInit, sessionId);
        telemetry5("preview-first-load", payload);
      }
    } catch {
    }
  }), channel.on(SHARE_POPOVER_OPENED, async () => {
    telemetry5("share", { action: "popover-opened" });
  }), channel.on(SHARE_STORY_LINK, async () => {
    telemetry5("share", { action: "story-link-copied" });
  }), channel.on(SHARE_ISOLATE_MODE, async () => {
    telemetry5("share", { action: "isolate-mode-opened" });
  }));
}

// src/core-server/utils/checklist.ts
import { createFileSystemCache, resolvePathInStorybookCache as resolvePathInStorybookCache2 } from "storybook/internal/common";
import { experimental_UniversalStore } from "storybook/internal/core-server";
import { logger } from "storybook/internal/node-logger";
import { telemetry as telemetry6 } from "storybook/internal/telemetry";

// ../../node_modules/es-toolkit/dist/predicate/isPrimitive.mjs
function isPrimitive(value) {
  return value == null || typeof value != "object" && typeof value != "function";
}

// ../../node_modules/es-toolkit/dist/predicate/isTypedArray.mjs
function isTypedArray(x) {
  return ArrayBuffer.isView(x) && !(x instanceof DataView);
}

// ../../node_modules/es-toolkit/dist/object/clone.mjs
function clone(obj) {
  if (isPrimitive(obj))
    return obj;
  if (Array.isArray(obj) || isTypedArray(obj) || obj instanceof ArrayBuffer || typeof SharedArrayBuffer < "u" && obj instanceof SharedArrayBuffer)
    return obj.slice(0);
  let prototype = Object.getPrototypeOf(obj), Constructor = prototype.constructor;
  if (obj instanceof Date || obj instanceof Map || obj instanceof Set)
    return new Constructor(obj);
  if (obj instanceof RegExp) {
    let newRegExp = new Constructor(obj);
    return newRegExp.lastIndex = obj.lastIndex, newRegExp;
  }
  if (obj instanceof DataView)
    return new Constructor(obj.buffer.slice(0));
  if (obj instanceof Error) {
    let newError = new Constructor(obj.message);
    return newError.stack = obj.stack, newError.name = obj.name, newError.cause = obj.cause, newError;
  }
  if (typeof File < "u" && obj instanceof File)
    return new Constructor([obj], obj.name, { type: obj.type, lastModified: obj.lastModified });
  if (typeof obj == "object") {
    let newObject = Object.create(prototype);
    return Object.assign(newObject, obj);
  }
  return obj;
}

// ../../node_modules/es-toolkit/dist/predicate/isPlainObject.mjs
function isPlainObject(value) {
  if (!value || typeof value != "object")
    return !1;
  let proto = Object.getPrototypeOf(value);
  return proto === null || proto === Object.prototype || Object.getPrototypeOf(proto) === null ? Object.prototype.toString.call(value) === "[object Object]" : !1;
}

// ../../node_modules/es-toolkit/dist/_internal/isUnsafeProperty.mjs
function isUnsafeProperty(key) {
  return key === "__proto__";
}

// ../../node_modules/es-toolkit/dist/object/mergeWith.mjs
function mergeWith(target, source, merge2) {
  let sourceKeys = Object.keys(source);
  for (let i = 0; i < sourceKeys.length; i++) {
    let key = sourceKeys[i];
    if (isUnsafeProperty(key))
      continue;
    let sourceValue = source[key], targetValue = target[key], merged = merge2(targetValue, sourceValue, key, target, source);
    merged !== void 0 ? target[key] = merged : Array.isArray(sourceValue) ? Array.isArray(targetValue) ? target[key] = mergeWith(targetValue, sourceValue, merge2) : target[key] = mergeWith([], sourceValue, merge2) : isPlainObject(sourceValue) ? isPlainObject(targetValue) ? target[key] = mergeWith(targetValue, sourceValue, merge2) : target[key] = mergeWith({}, sourceValue, merge2) : (targetValue === void 0 || sourceValue !== void 0) && (target[key] = sourceValue);
  }
  return target;
}

// ../../node_modules/es-toolkit/dist/string/words.mjs
var CASE_SPLIT_PATTERN = new RegExp("\\p{Lu}?\\p{Ll}+|[0-9]+|\\p{Lu}+(?!\\p{Ll})|\\p{Emoji_Presentation}|\\p{Extended_Pictographic}|\\p{L}+", "gu");

// ../../node_modules/es-toolkit/dist/object/toMerged.mjs
function toMerged(target, source) {
  return mergeWith(clone(target), source, function mergeRecursively(targetValue, sourceValue) {
    if (Array.isArray(sourceValue))
      return Array.isArray(targetValue) ? mergeWith(clone(targetValue), sourceValue, mergeRecursively) : mergeWith([], sourceValue, mergeRecursively);
    if (isPlainObject(sourceValue))
      return isPlainObject(targetValue) ? mergeWith(clone(targetValue), sourceValue, mergeRecursively) : mergeWith({}, sourceValue, mergeRecursively);
  });
}

// src/shared/checklist-store/checklistData.state.ts
var initialState = {
  items: {
    accessibilityTests: { status: "open" },
    autodocs: { status: "open" },
    ciTests: { status: "open" },
    controls: { status: "open" },
    coverage: { status: "open" },
    guidedTour: { status: "open" },
    installA11y: { status: "open" },
    installChromatic: { status: "open" },
    installDocs: { status: "open" },
    installVitest: { status: "open" },
    mdxDocs: { status: "open" },
    moreComponents: { status: "open" },
    moreStories: { status: "open" },
    onboardingSurvey: { status: "open" },
    organizeStories: { status: "open" },
    publishStorybook: { status: "open" },
    renderComponent: { status: "open" },
    runTests: { status: "open" },
    viewports: { status: "open" },
    visualTests: { status: "open" },
    whatsNewStorybook10: { status: "open" },
    writeInteractions: { status: "open" }
  },
  widget: {}
};

// src/shared/checklist-store/index.ts
var UNIVERSAL_CHECKLIST_STORE_OPTIONS = {
  id: "storybook/checklist",
  initialState
};

// src/core-server/utils/checklist.ts
async function initializeChecklist() {
  try {
    let store = experimental_UniversalStore.create({
      ...UNIVERSAL_CHECKLIST_STORE_OPTIONS,
      leader: !0
    }), cache = createFileSystemCache({
      basePath: resolvePathInStorybookCache2("checklist"),
      ns: "storybook"
    }), [[userState, saveUserState], [projectState, saveProjectState]] = await Promise.all([
      globalSettings().then((settings) => {
        let save = throttle(() => settings.save(), 1e3), state = {
          items: settings.value.checklist?.items ?? {},
          widget: settings.value.checklist?.widget ?? {}
        };
        return [state, ({
          items = state.items,
          widget = state.widget
        }) => {
          settings.value.checklist = { items, widget }, save();
        }];
      }),
      cache.get("state").then((cachedState) => [{ items: cachedState?.items ?? {} }, ({ items }) => cache.set("state", { items })])
    ]);
    store.setState(
      (value) => ({
        ...toMerged(value, toMerged(userState, projectState)),
        loaded: !0
      })
    ), store.onStateChange((state, previousState) => {
      let entries = Object.entries(state.items), projectValues = {}, userValues = {};
      if (entries.forEach(([id, { status, mutedAt }]) => {
        status === "done" ? projectValues[id] = { status } : (status === "accepted" || status === "skipped") && (userValues[id] = { status }), mutedAt && (userValues[id] = {
          ...userValues[id],
          mutedAt
        });
      }), saveProjectState({ items: projectValues }), saveUserState({ items: userValues, widget: state.widget }), !previousState.loaded)
        return;
      let { mutedItems, statusItems } = entries.reduce(
        (acc, [item, { mutedAt, status }]) => {
          let prev = previousState.items[item];
          return mutedAt !== prev?.mutedAt && acc.mutedItems.push(item), status !== prev?.status && acc.statusItems.push(item), acc;
        },
        { mutedItems: [], statusItems: [] }
      );
      mutedItems.length > 0 && telemetry6("onboarding-checklist-muted", {
        items: mutedItems,
        completedItems: entries.reduce((acc, [id, { status }]) => status === "done" || status === "accepted" ? acc.concat([id]) : acc, []),
        skippedItems: entries.reduce((acc, [id, { status }]) => status === "skipped" ? acc.concat([id]) : acc, [])
      }), statusItems.forEach((item) => {
        let { status } = state.items[item];
        telemetry6("onboarding-checklist-status", { item, status });
      });
    });
  } catch (err) {
    logger.error("Failed to initialize checklist"), logger.error(err);
  }
}

// src/core-server/utils/constants.ts
var defaultStaticDirs = [
  {
    from: join(resolvePackageDir("storybook"), "assets/browser"),
    to: "/sb-common-assets"
  }
], defaultFavicon = join(resolvePackageDir("storybook"), "assets/browser/favicon.svg");

// src/core-server/utils/save-story/save-story.ts
import { writeFile } from "node:fs/promises";
import { basename, join as join3 } from "node:path";
import { formatFileContent } from "storybook/internal/common";
import {
  SAVE_STORY_REQUEST,
  SAVE_STORY_RESPONSE,
  STORY_RENDERED
} from "storybook/internal/core-events";
import { storyNameFromExport, toId } from "storybook/internal/csf";
import { printCsf, readCsf } from "storybook/internal/csf-tools";
import { logger as logger2 } from "storybook/internal/node-logger";
import { isExampleStoryId, telemetry as telemetry7 } from "storybook/internal/telemetry";

// src/core-server/utils/save-story/duplicate-story-with-new-name.ts
import { types as t2, traverse as traverse2 } from "storybook/internal/babel";

// src/core-server/utils/save-story/utils.ts
var SaveStoryError = class extends Error {
};

// src/core-server/utils/save-story/duplicate-story-with-new-name.ts
var duplicateStoryWithNewName = (csfFile, storyName, newStoryName) => {
  let node = csfFile._storyExports[storyName], cloned = t2.cloneNode(node);
  if (!cloned)
    throw new SaveStoryError("cannot clone Node");
  let found = !1;
  if (traverse2(cloned, {
    Identifier(path) {
      found || path.node.name === storyName && (found = !0, path.node.name = newStoryName);
    },
    ObjectProperty(path) {
      let key = path.get("key");
      key.isIdentifier() && key.node.name === "args" && path.remove();
    },
    noScope: !0
  }), !(t2.isCallExpression(cloned.init) && t2.isMemberExpression(cloned.init.callee) && t2.isIdentifier(cloned.init.callee.property) && cloned.init.callee.property.name === "story") && (t2.isArrowFunctionExpression(cloned.init) || t2.isCallExpression(cloned.init)))
    throw new SaveStoryError("Creating a new story based on a CSF2 story is not supported");
  return traverse2(csfFile._ast, {
    Program(path) {
      path.pushContainer(
        "body",
        t2.exportNamedDeclaration(t2.variableDeclaration("const", [cloned]))
      );
    }
  }), cloned;
};

// src/core-server/utils/save-story/update-args-in-csf-file.ts
import { types as t4, traverse as traverse3 } from "storybook/internal/babel";

// src/core-server/utils/save-story/valueToAST.ts
import { parser as parser2, types as t3 } from "storybook/internal/babel";
function valueToAST(literal) {
  if (literal === null)
    return t3.nullLiteral();
  switch (typeof literal) {
    case "function":
      return parser2.parse(literal.toString(), {
        allowReturnOutsideFunction: !0,
        allowSuperOutsideMethod: !0
      }).program.body[0]?.expression;
    case "number":
      return t3.numericLiteral(literal);
    case "string":
      return t3.stringLiteral(literal);
    case "boolean":
      return t3.booleanLiteral(literal);
    case "undefined":
      return t3.identifier("undefined");
    default:
      return Array.isArray(literal) ? t3.arrayExpression(literal.map(valueToAST)) : t3.objectExpression(
        Object.keys(literal).filter((k) => typeof literal[k] < "u").map((k) => {
          let value = literal[k];
          return t3.objectProperty(t3.stringLiteral(k), valueToAST(value));
        })
      );
  }
}

// src/core-server/utils/save-story/update-args-in-csf-file.ts
var updateArgsInCsfFile = async (node, input) => {
  let found = !1, args = Object.fromEntries(
    Object.entries(input).map(([k, v]) => [k, valueToAST(v)])
  );
  if (!(t4.isCallExpression(node) && t4.isMemberExpression(node.callee) && t4.isIdentifier(node.callee.property) && node.callee.property.name === "story") && (t4.isArrowFunctionExpression(node) || t4.isCallExpression(node)))
    throw new SaveStoryError("Updating a CSF2 story is not supported");
  if (t4.isObjectExpression(node)) {
    let properties = node.properties, argsProperty = properties.find((property) => {
      if (t4.isObjectProperty(property)) {
        let key = property.key;
        return t4.isIdentifier(key) && key.name === "args";
      }
      return !1;
    });
    if (argsProperty) {
      if (t4.isObjectProperty(argsProperty)) {
        let a = argsProperty.value;
        if (t4.isObjectExpression(a)) {
          a.properties.forEach((p) => {
            if (t4.isObjectProperty(p)) {
              let key = p.key;
              t4.isIdentifier(key) && key.name in args && (p.value = args[key.name], delete args[key.name]);
            }
          });
          let remainder = Object.entries(args);
          Object.keys(args).length && remainder.forEach(([key, value]) => {
            a.properties.push(t4.objectProperty(t4.identifier(key), value));
          });
        }
      }
    } else
      properties.unshift(
        t4.objectProperty(
          t4.identifier("args"),
          t4.objectExpression(
            Object.entries(args).map(([key, value]) => t4.objectProperty(t4.identifier(key), value))
          )
        )
      );
    return;
  }
  traverse3(node, {
    ObjectExpression(path) {
      if (found)
        return;
      found = !0;
      let argsProperty = path.get("properties").find((property) => {
        if (property.isObjectProperty()) {
          let key = property.get("key");
          return key.isIdentifier() && key.node.name === "args";
        }
        return !1;
      });
      if (argsProperty) {
        if (argsProperty.isObjectProperty()) {
          let a = argsProperty.get("value");
          if (a.isObjectExpression()) {
            a.traverse({
              ObjectProperty(p) {
                let key = p.get("key");
                key.isIdentifier() && key.node.name in args && (p.get("value").replaceWith(args[key.node.name]), delete args[key.node.name]);
              },
              noScope: !0
            });
            let remainder = Object.entries(args);
            Object.keys(args).length && remainder.forEach(([key, value]) => {
              a.pushContainer("properties", t4.objectProperty(t4.identifier(key), value));
            });
          }
        }
      } else
        path.unshiftContainer(
          "properties",
          t4.objectProperty(
            t4.identifier("args"),
            t4.objectExpression(
              Object.entries(args).map(([key, value]) => t4.objectProperty(t4.identifier(key), value))
            )
          )
        );
    },
    noScope: !0
  });
};

// src/core-server/utils/save-story/save-story.ts
var parseArgs = (args) => JSON.parse(args, (_, value) => value === "__sb_empty_function_arg__" ? () => {
} : value), removeExtraNewlines = (code, name) => {
  let anything = "([\\s\\S])", newline = "(\\r\\n|\\r|\\n)", closing = newline + "};" + newline, regex = new RegExp(
    // Looks for an export by the given name, considers the first closing brace on its own line
    // to be the end of the story definition.
    `^(?<before>${anything}*)(?<story>export const ${name} =${anything}+?${closing})(?<after>${anything}*)$`
  ), { before, story, after } = code.match(regex)?.groups || {};
  return story ? before + story.replaceAll(/(\r\n|\r|\n)(\r\n|\r|\n)([ \t]*[a-z0-9_]+): /gi, "$2$3:") + after : code;
};
function initializeSaveStory(channel, options, coreConfig) {
  channel.on(SAVE_STORY_REQUEST, async ({ id, payload }) => {
    let { csfId, importPath, args, name } = payload, newStoryId, newStoryName, sourceFileName, sourceFilePath, sourceStoryName;
    try {
      sourceFileName = basename(importPath), sourceFilePath = join3(process.cwd(), importPath);
      let csf = await readCsf(sourceFilePath, {
        makeTitle: (userTitle) => userTitle || "myTitle"
      }), parsed = csf.parse(), stories = Object.entries(parsed._stories), [componentId, storyId] = csfId.split("--");
      newStoryName = name && storyNameFromExport(name), newStoryId = newStoryName && toId(componentId, newStoryName);
      let [storyName] = stories.find(([key, value]) => value.id.endsWith(`--${storyId}`)) || [];
      if (!storyName)
        throw new SaveStoryError("Source story not found.");
      if (name && csf.getStoryExport(name))
        throw new SaveStoryError("Story already exists.");
      sourceStoryName = storyNameFromExport(storyName), await updateArgsInCsfFile(
        name ? duplicateStoryWithNewName(parsed, storyName, name) : csf.getStoryExport(storyName),
        args ? parseArgs(args) : {}
      );
      let code = await formatFileContent(
        sourceFilePath,
        removeExtraNewlines(printCsf(csf).code, name || storyName)
      );
      await Promise.all([
        new Promise((resolve) => {
          channel.on(STORY_RENDERED, resolve), setTimeout(() => resolve(channel.off(STORY_RENDERED, resolve)), 3e3);
        }),
        writeFile(sourceFilePath, code)
      ]), channel.emit(SAVE_STORY_RESPONSE, {
        id,
        success: !0,
        payload: {
          csfId,
          newStoryId,
          newStoryName,
          newStoryExportName: name,
          sourceFileContent: code,
          sourceFileName,
          sourceStoryName,
          sourceStoryExportName: storyName
        },
        error: null
      });
      let isCLIExample = isExampleStoryId(newStoryId ?? csfId);
      !coreConfig.disableTelemetry && !isCLIExample && await telemetry7("save-story", {
        action: name ? "createStory" : "updateStory",
        success: !0
      });
    } catch (error) {
      channel.emit(SAVE_STORY_RESPONSE, {
        id,
        success: !1,
        error: error instanceof SaveStoryError ? error.message : "Unknown error"
      }), logger2.error(
        `Error writing to ${sourceFilePath}:
${error.stack || error.message || error.toString()}`
      ), !coreConfig.disableTelemetry && !(error instanceof SaveStoryError) && await telemetry7("save-story", {
        action: name ? "createStory" : "updateStory",
        success: !1,
        error
      });
    }
  });
}

// src/core-server/utils/whats-new.ts
import { writeFile as writeFile2 } from "node:fs/promises";
import { findConfigFile, loadMainConfig } from "storybook/internal/common";
import {
  REQUEST_WHATS_NEW_DATA,
  RESULT_WHATS_NEW_DATA,
  SET_WHATS_NEW_CACHE,
  TELEMETRY_ERROR,
  TOGGLE_WHATS_NEW_NOTIFICATIONS
} from "storybook/internal/core-events";
import { printConfig, readConfig } from "storybook/internal/csf-tools";
import { logger as logger3 } from "storybook/internal/node-logger";
import { telemetry as telemetry8 } from "storybook/internal/telemetry";
var WHATS_NEW_CACHE = "whats-new-cache", WHATS_NEW_URL = "https://storybook.js.org/whats-new/v1";
function initializeWhatsNew(channel, options, coreOptions) {
  channel.on(SET_WHATS_NEW_CACHE, async (data) => {
    let cache = await options.cache.get(WHATS_NEW_CACHE).catch((e) => (logger3.verbose(e), {}));
    await options.cache.set(WHATS_NEW_CACHE, { ...cache, ...data });
  }), channel.on(REQUEST_WHATS_NEW_DATA, async () => {
    try {
      let post = await fetch(WHATS_NEW_URL).then(async (response) => {
        if (response.ok)
          return response.json();
        throw response;
      }), disableWhatsNewNotifications = (await loadMainConfig({ configDir: options.configDir })).core?.disableWhatsNewNotifications === !0, cache = await options.cache.get(WHATS_NEW_CACHE) ?? {}, data = {
        ...post,
        status: "SUCCESS",
        postIsRead: post.url === cache.lastReadPost,
        showNotification: post.url !== cache.lastDismissedPost && post.url !== cache.lastReadPost,
        disableWhatsNewNotifications
      };
      channel.emit(RESULT_WHATS_NEW_DATA, { data });
    } catch (e) {
      logger3.verbose(e instanceof Error ? e.message : String(e)), channel.emit(RESULT_WHATS_NEW_DATA, {
        data: { status: "ERROR" }
      });
    }
  }), channel.on(
    TOGGLE_WHATS_NEW_NOTIFICATIONS,
    async ({ disableWhatsNewNotifications }) => {
      let isTelemetryEnabled = coreOptions.disableTelemetry !== !0;
      try {
        let mainPath = findConfigFile("main", options.configDir);
        invariant(mainPath, `unable to find Storybook main file in ${options.configDir}`);
        let main = await readConfig(mainPath);
        if (!main._exportsObject)
          throw new Error(
            "Unable to parse Storybook main file while trying to read 'core' property"
          );
        main.setFieldValue(["core", "disableWhatsNewNotifications"], disableWhatsNewNotifications), await writeFile2(mainPath, printConfig(main).code), isTelemetryEnabled && await telemetry8("core-config", { disableWhatsNewNotifications });
      } catch (error) {
        invariant(error instanceof Error), isTelemetryEnabled && await sendTelemetryError(error, "core-config", {
          cliOptions: options,
          presetOptions: {
            ...options,
            corePresets: [],
            overridePresets: []
          },
          skipPrompt: !0
        });
      }
    }
  ), channel.on(TELEMETRY_ERROR, async (error) => {
    coreOptions.disableTelemetry !== !0 && await sendTelemetryError(error, "browser", {
      cliOptions: options,
      presetOptions: {
        ...options,
        corePresets: [],
        overridePresets: []
      },
      skipPrompt: !0
    });
  });
}

// src/core-server/presets/common-preset.ts
var interpolate = (string, data = {}) => Object.entries(data).reduce((acc, [k, v]) => acc.replace(new RegExp(`%${k}%`, "g"), v), string), staticDirs = async (values = []) => [
  ...defaultStaticDirs,
  ...values
], favicon = async (value, options) => {
  if (value)
    return value;
  let staticDirsValue = await options.presets.apply("staticDirs"), faviconPaths = (staticDirsValue ? staticDirsValue.map((dir) => typeof dir == "string" ? dir : `${dir.from}:${dir.to}`) : []).map((dir) => {
    let results = [], normalizedDir = staticDirsValue && !isAbsolute(dir) ? getDirectoryFromWorkingDir({
      configDir: options.configDir,
      workingDir: process.cwd(),
      directory: dir
    }) : dir, { staticPath, targetEndpoint } = parseStaticDir(normalizedDir);
    return ["/favicon.svg", "/favicon.ico"].includes(targetEndpoint) && results.push(staticPath), targetEndpoint === "/" && (results.push(join(staticPath, "favicon.svg")), results.push(join(staticPath, "favicon.ico"))), results.filter((path) => existsSync2(path));
  }).reduce((l1, l2) => l1.concat(l2), []);
  return faviconPaths.length > 1 && logger4.debug(import_ts_dedent.dedent`
      Looks like multiple favicons were detected. Using the first one.

      ${faviconPaths.join(", ")}
    `), faviconPaths[0] || defaultFavicon;
}, babel = async (_, options) => {
  let { presets } = options, babelDefault = await presets.apply("babelDefault", {}, options) ?? {};
  return {
    ...babelDefault,
    // This override makes sure that we will never transpile babel further down then the browsers that storybook supports.
    // This is needed to support the mount property of the context described here:
    // https://storybook.js.org/docs/writing-tests/interaction-testing#run-code-before-each-story-in-a-file
    overrides: [
      ...babelDefault?.overrides ?? [],
      {
        include: /\.(story|stories)\.[cm]?[jt]sx?$/,
        presets: [
          [
            "@babel/preset-env",
            {
              bugfixes: !0,
              targets: {
                // This is the same browser supports that we use to bundle our manager and preview code.
                chrome: 100,
                safari: 15,
                firefox: 91
              }
            }
          ]
        ]
      }
    ]
  };
}, title = (previous, options) => previous || options.packageJson?.name || !1, logLevel = (previous, options) => previous || options.loglevel || "info", previewHead = async (base, { configDir, presets }) => {
  let interpolations = await presets.apply("env");
  return getPreviewHeadTemplate(configDir, interpolations);
}, env = async () => {
  let { raw } = await loadEnvs({ production: !0 });
  return raw;
}, previewBody = async (base, { configDir, presets }) => {
  let interpolations = await presets.apply("env");
  return getPreviewBodyTemplate(configDir, interpolations);
}, typescript = () => ({
  check: !1,
  // 'react-docgen' faster than `react-docgen-typescript` but produces lower quality results
  reactDocgen: "react-docgen",
  reactDocgenTypescriptOptions: {
    shouldExtractLiteralValuesFromEnum: !0,
    shouldRemoveUndefinedFromOptional: !0,
    propFilter: (prop) => prop.parent ? !/node_modules/.test(prop.parent.fileName) : !0,
    // NOTE: this default cannot be changed
    savePropValueAsString: !0
  }
}), experimental_serverAPI = (extension, options) => {
  let removeAddon = removeAddonBase, packageManager = JsPackageManagerFactory.getPackageManager({
    configDir: options.configDir
  });
  return options.disableTelemetry || (removeAddon = async (id, opts) => (await telemetry9("remove", { addon: id, source: "api" }), removeAddonBase(id, { ...opts, packageManager }))), { ...extension, removeAddon };
}, core = async (existing, options) => ({
  ...existing,
  channelOptions: {
    ...existing?.channelOptions ?? {},
    ...options.configType === "DEVELOPMENT" ? { wsToken: getWsToken() } : {}
  },
  disableTelemetry: options.disableTelemetry === !0,
  enableCrashReports: options.enableCrashReports || optionalEnvToBoolean(process.env.STORYBOOK_ENABLE_CRASH_REPORTS)
}), features = async (existing) => ({
  ...existing,
  argTypeTargetsV7: !0,
  legacyDecoratorFileOrder: !1,
  disallowImplicitActionsInRenderV8: !0,
  viewport: !0,
  highlight: !0,
  controls: !0,
  interactions: !0,
  actions: !0,
  backgrounds: !0,
  outline: !0,
  measure: !0,
  sidebarOnboardingChecklist: !0,
  componentsManifest: !0
}), csfIndexer = {
  test: /(stories|story)\.(m?js|ts)x?$/,
  createIndex: async (fileName, options) => {
    let code = (await readFile4(fileName, "utf-8")).toString();
    return code.trim().length === 0 ? (logger4.debug(`The file ${fileName} is empty. Skipping indexing.`), []) : loadCsf(code, { ...options, fileName }).parse().indexInputs;
  }
}, experimental_indexers = (existingIndexers) => [csfIndexer].concat(existingIndexers || []), frameworkOptions = async (_, options) => {
  let config = await options.presets.apply("framework");
  return typeof config == "string" ? {} : typeof config > "u" ? null : config.options;
}, managerHead = async (_, options) => {
  let location = join(options.configDir, "manager-head.html");
  if (existsSync2(location)) {
    let contents = readFile4(location, { encoding: "utf8" }), interpolations = options.presets.apply("env");
    return interpolate(await contents, await interpolations);
  }
  return "";
}, channelToken = async (value) => value, experimental_serverChannel = async (channel, options) => {
  let coreOptions = await options.presets.apply("core");
  return initializeChecklist(), initializeWhatsNew(channel, options, coreOptions), initializeSaveStory(channel, options, coreOptions), initFileSearchChannel(channel, options, coreOptions), initCreateNewStoryChannel(channel, options, coreOptions), initGhostStoriesChannel(channel, options, coreOptions), initOpenInEditorChannel(channel, options, coreOptions), initTelemetryChannel(channel, options), channel;
}, resolvedReact = async (existing) => {
  try {
    return {
      ...existing,
      react: resolvePackageDir("react"),
      reactDom: resolvePackageDir("react-dom")
    };
  } catch {
    return existing;
  }
}, managerEntries = async (existing) => [
  join(resolvePackageDir("storybook"), "dist/core-server/presets/common-manager.js"),
  ...existing || []
], storyIndexGeneratorPromise, storyIndexGenerator = async (_, options) => storyIndexGeneratorPromise || (storyIndexGeneratorPromise = (async () => {
  let workingDir = process.cwd(), configDir = options.configDir, stories = await options.presets.apply("stories"), normalizedStories = normalizeStories(stories, {
    configDir,
    workingDir
  }), [indexers, docs] = await Promise.all([
    options.presets.apply("experimental_indexers", []),
    options.presets.apply("docs")
  ]), generator = new StoryIndexGenerator(normalizedStories, {
    workingDir,
    configDir,
    indexers,
    docs
  });
  return await generator.initialize(), generator;
})(), storyIndexGeneratorPromise);
export {
  babel,
  channelToken,
  core,
  csfIndexer,
  env,
  experimental_indexers,
  experimental_serverAPI,
  experimental_serverChannel,
  favicon,
  features,
  frameworkOptions,
  logLevel,
  managerEntries,
  managerHead,
  previewBody,
  previewHead,
  resolvedReact,
  staticDirs,
  storyIndexGenerator,
  title,
  typescript
};
