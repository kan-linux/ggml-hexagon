import { type ESTreeAST, type SvelteAST } from '../../../parser/ast.js';
interface Params {
    component: SvelteAST.Component;
    comment?: SvelteAST.Comment;
}
/**
 * Codemod to transform AST node of `<Meta>` component to `defineMeta`
 *
 * @example
 * ```diff
 * - <Meta title="Atom/Button" component={Button} args={{ ... }} />
 * + const { Story } = defineMeta({
 * +   title: "Atom/Button",
 * +   component: Button,
 * +   args: { ... },
 * + });
 * ```
 */
export declare function transformComponentMetaToDefineMeta(params: Params): ESTreeAST.VariableDeclaration;
export {};
