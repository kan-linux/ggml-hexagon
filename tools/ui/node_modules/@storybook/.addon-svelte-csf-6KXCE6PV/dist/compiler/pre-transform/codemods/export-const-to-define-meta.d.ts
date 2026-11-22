import type { ESTreeAST } from '../../../parser/ast.js';
/**
 * Codemod to transform AST node of `export const meta` export named declaration to `defineMeta` variable declaration.
 *
 * @example
 * ```diff
 * - export const meta = {
 * + const { Story } = defineMeta({
 *     title: "Atom/Button",
 *     component: Button,
 *     args: {
 *         // ...
 *     },
 *     // .. and more
 * - } satisfies Meta<Button>;
 * + });
 * ```
 */
export declare function transformExportMetaToDefineMeta(exportMeta: ESTreeAST.ExportNamedDeclaration): ESTreeAST.VariableDeclaration;
