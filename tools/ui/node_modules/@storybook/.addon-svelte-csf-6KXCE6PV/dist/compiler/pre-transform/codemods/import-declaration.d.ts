import type { ESTreeAST } from '../../../parser/ast.js';
interface Params {
    node: ESTreeAST.ImportDeclaration;
    filename?: string;
}
/**
 *
 * Codemod to transform AST node of {@link ImportDeclaration} specifiers.
 *
 * @example
 * ```diff
 * import {
 * - Story,
 * - Template,
 * + defineMeta,
 * } from "@storybook/addon-svelte-csf";
 * ```
 */
export declare function transformImportDeclaration(params: Params): ESTreeAST.ImportDeclaration;
export {};
