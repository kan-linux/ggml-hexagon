import type { ProgramNode } from 'rollup';
import type { ESTreeAST } from '../../ast.js';
/**
 * Important AST nodes from the compiled output of a single `*.stories.svelte` file.
 * They are needed for further code transformation by this addon.
 * Powered by `rollup`'s internal [`this.parse()`](https://rollupjs.org/plugin-development/#this-parse)
 */
export interface CompiledASTNodes {
    /**
     * Import specifier for `defineMeta` imported from this addon package.
     * Could be renamed - e.g. `import { defineMeta } from "@storybook/addon-svelte-csf"`
     */
    defineMetaImport: ESTreeAST.ImportSpecifier;
    /**
     * Variable declaration: `const { Story } = defineMeta({ })`
     * Could be destructured with rename - e.g. `const { Story: S } = defineMeta({ ... })`
     */
    defineMetaVariableDeclaration: ESTreeAST.VariableDeclaration;
    /**
     * Store the `export default declaration`, we will need to remove it later.
     * Why? Storybook expects `export default meta`, instead of what `@sveltejs/vite-plugin-svelte` will produce.
     */
    exportDefault: ESTreeAST.ExportDefaultDeclaration;
    /**
     * An identifier for the addon's component `<Story />`.
     * It could be destructured with rename - e.g. `const { Story: S } = defineMeta({ ... })`
     */
    storyIdentifier: ESTreeAST.Identifier;
    /**
     * A function declaration for the main Svelte component which is the `*.stories.svelte` file.
     */
    storiesFunctionDeclaration: ESTreeAST.FunctionDeclaration;
}
interface Params {
    ast: ESTreeAST.Program | ProgramNode;
    filename?: string;
}
/**
 * Extract compiled AST nodes from Vite _(via `rollup`)_.
 * Those nodes are required for further code transformation.
 */
export declare function extractCompiledASTNodes(params: Params): Promise<CompiledASTNodes>;
export {};
