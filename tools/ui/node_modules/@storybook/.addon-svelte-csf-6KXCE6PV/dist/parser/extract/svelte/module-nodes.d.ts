import type { ESTreeAST, SvelteAST } from '../../ast.js';
interface Result {
    /**
     * Import specifier for `defineMeta` imported from this addon package.
     * Could be renamed - e.g. `import { defineMeta as df } from "@storybook/addon-svelte-csf"`
     */
    defineMetaImport: ESTreeAST.ImportSpecifier;
    /**
     * Variable declaration: `const { Story } = defineMeta({ })`
     * Could be destructured with rename - e.g. `const { Story: S } = defineMeta({ ... })`
     */
    defineMetaVariableDeclaration: ESTreeAST.VariableDeclaration;
    /**
     * An identifier for the addon's component `<Story />`.
     * It could be destructured with rename - e.g. `const { Story: S } = defineMeta({ ... })`
     */
    storyIdentifier: ESTreeAST.Identifier;
}
interface Params {
    module: SvelteAST.Root['module'];
    filename?: string;
}
/**
 * Extract Svelte AST nodes via `svelte.compile`,
 * and from the module tag - `<script module>`.
 * They are needed for further code analysis/transformation.
 */
export declare function extractModuleNodes(options: Params): Promise<Result>;
export {};
