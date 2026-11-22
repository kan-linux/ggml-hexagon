import dedent from 'dedent';
import { StorybookSvelteCSFError } from '../../../error.js';
export class MissingImportedDefineMetaError extends StorybookSvelteCSFError {
    category = StorybookSvelteCSFError.CATEGORY.parserExtractCompiled;
    code = 1;
    documentation = true;
    constructor(filename) {
        super({ filename });
    }
    template() {
        return dedent `
      Could not find the import statement of 'defineMeta' from the "${StorybookSvelteCSFError.packageName}" in the compiled output of: ${this.filepathURL}
    `;
    }
}
export class MissingDefineMetaVariableDeclarationError extends StorybookSvelteCSFError {
    category = StorybookSvelteCSFError.CATEGORY.parserExtractCompiled;
    code = 2;
    documentation = true;
    constructor(filename) {
        super({ filename });
    }
    template() {
        return dedent `
			Could not find variable declaration from 'defineMeta' call in the compiled output of the stories file: ${this.filepathURL}
    `;
    }
}
export class NoExportDefaultError extends StorybookSvelteCSFError {
    category = StorybookSvelteCSFError.CATEGORY.parserExtractCompiled;
    code = 3;
    documentation = true;
    constructor(filename) {
        super({ filename });
    }
    template() {
        return dedent `
			Could not find 'export default' in the compiled output of the stories file: ${this.filepathURL}
    `;
    }
}
export class NoStoryIdentifierFoundError extends StorybookSvelteCSFError {
    category = StorybookSvelteCSFError.CATEGORY.parserExtractCompiled;
    code = 4;
    documentation = true;
    constructor(filename) {
        super({ filename });
    }
    template() {
        return dedent `
			Could not find a 'Story' identifier in the compiled output of the stories file: ${this.filepathURL}
    `;
    }
}
export class NoStoriesFunctionDeclarationError extends StorybookSvelteCSFError {
    category = StorybookSvelteCSFError.CATEGORY.parserExtractCompiled;
    code = 5;
    documentation = true;
    constructor(filename) {
        super({ filename });
    }
    template() {
        return dedent `
			Could not find the stories component '*.stories.svelte' function declaration compiled output of the stories file: ${this.filepathURL}
    `;
    }
}
export class NoCompiledStoryPropsObjectExpression extends StorybookSvelteCSFError {
    category = StorybookSvelteCSFError.CATEGORY.parserExtractCompiled;
    code = 6;
    documentation = true;
    node;
    constructor({ filename, node, }) {
        super({ filename });
        this.node = node;
    }
    template() {
        return dedent `
      Failed to extract compiled Story component props as object expression in the compiled output of stories file: ${this.filepathURL}
    `;
    }
}
