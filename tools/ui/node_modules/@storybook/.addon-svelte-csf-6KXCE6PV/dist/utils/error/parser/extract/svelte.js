import dedent from 'dedent';
import { StorybookSvelteCSFError } from '../../../error.js';
const BASE_INITIAL_SNIPPET = dedent `
<script module>
  import { defineMeta } from "@storybook/addon-svelte-csf";
  
  const { Story } = defineMeta({});
</script>
`;
export class MissingModuleTagError extends StorybookSvelteCSFError {
    category = StorybookSvelteCSFError.CATEGORY.parserExtractSvelte;
    code = 1;
    documentation = true;
    constructor(filename) {
        super({ filename });
    }
    template() {
        return dedent `
      The file '${this.filepathURL}'
      does not have a module context (<script module> ... </script>).

      defineMeta(...) should be called inside a module script tag, like so:

      ${BASE_INITIAL_SNIPPET}
    `;
    }
}
export class DefaultOrNamespaceImportUsedError extends StorybookSvelteCSFError {
    category = StorybookSvelteCSFError.CATEGORY.parserExtractSvelte;
    code = 2;
    documentation = true;
    constructor(filename) {
        super({ filename });
    }
    template() {
        return dedent `
      The file '${this.filepathURL}'
      is using the default/namespace import from "${StorybookSvelteCSFError.packageName}".
      Only named imports are supported.
    `;
    }
}
export class MissingDefineMetaImportError extends StorybookSvelteCSFError {
    category = StorybookSvelteCSFError.CATEGORY.parserExtractSvelte;
    code = 3;
    documentation = true;
    constructor(filename) {
        super({ filename });
    }
    template() {
        return dedent `
      The file '${this.filepathURL}'
      does not import defineMeta from "${StorybookSvelteCSFError.packageName}" inside the module context.

      Make sure to import defineMeta from the package and use it inside the module context like so:

      ${BASE_INITIAL_SNIPPET}
    `;
    }
}
export class MissingDefineMetaVariableDeclarationError extends StorybookSvelteCSFError {
    category = StorybookSvelteCSFError.CATEGORY.parserExtractSvelte;
    code = 4;
    documentation = true;
    constructor(filename) {
        super({ filename });
    }
    template() {
        return dedent `
    The file '${this.filepathURL}'
    does not store the result of calling defineMeta(). While defineMeta() might have been called,
    it's return value needs to be stored and destructured for the parsing to succeed, eg.:

    ${BASE_INITIAL_SNIPPET}
    `;
    }
}
export class NoStoryComponentDestructuredError extends StorybookSvelteCSFError {
    category = StorybookSvelteCSFError.CATEGORY.parserExtractSvelte;
    code = 5;
    documentation = true;
    defineMetaImport;
    constructor({ filename, defineMetaImport, }) {
        super({ filename });
        this.defineMetaImport = defineMetaImport;
    }
    template() {
        return dedent `
      The file '${this.filepathURL}'
      does not destructure the Story component from the '${this.defineMetaImport.local.name}({ ... })' function call.
      eg.:

      ${BASE_INITIAL_SNIPPET}
    `;
    }
}
export class GetDefineMetaFirstArgumentError extends StorybookSvelteCSFError {
    category = StorybookSvelteCSFError.CATEGORY.parserExtractSvelte;
    code = 6;
    documentation = true;
    defineMetaVariableDeclaration;
    constructor({ filename, defineMetaVariableDeclaration, }) {
        super({ filename });
        this.defineMetaVariableDeclaration = defineMetaVariableDeclaration;
    }
    template() {
        return dedent `
      The file '${this.filepathURL}'
      passes an invalid first argument to the 'defineMeta' call.

      The first argument must be an object expression with the meta properties set.
    `;
    }
}
export class InvalidStoryTemplateAttributeError extends StorybookSvelteCSFError {
    category = StorybookSvelteCSFError.CATEGORY.parserExtractSvelte;
    code = 7;
    documentation = true;
    templateAttribute;
    constructor({ filename, component, templateAttribute, }) {
        super({ filename, component });
        this.templateAttribute = templateAttribute;
    }
    template() {
        return dedent `
      Component '${this.quickStoryRawCodeIdentifier}' in the stories file '${this.filepathURL}'
      has an invalid 'template'-prop.

      When set, the 'template'-prop must be an expression with reference to a root-level snippet.

      Eg.:

      {#snippet template()}
        ...
      {/snippet}

      <Story name="${this.storyNameFromAttribute}" template={template} />
    `;
    }
}
export class IndexerParseError extends StorybookSvelteCSFError {
    category = StorybookSvelteCSFError.CATEGORY.parserExtractSvelte;
    code = 9;
    documentation = true;
    constructor(options) {
        super({}, options);
    }
    template() {
        return dedent `
      Storybook stories indexer parser threw an unrecognized error.
      If you see this error, please report it on the issue tracker on GitHub.
    `;
    }
}
