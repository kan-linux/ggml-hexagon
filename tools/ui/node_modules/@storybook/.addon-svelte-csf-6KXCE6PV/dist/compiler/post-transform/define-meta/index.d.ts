import type MagicString from 'magic-string';
import { type ESTreeAST } from '../../../parser/ast.js';
import type { CompiledASTNodes } from '../../../parser/extract/compiled/nodes.js';
import type { SvelteASTNodes } from '../../../parser/extract/svelte/nodes.js';
interface Params {
    code: MagicString;
    nodes: {
        compiled: CompiledASTNodes;
        svelte: SvelteASTNodes;
    };
    filename?: string;
}
/**
 * Attempt to transform compiled `defineMeta()` when necessary.
 * And in the end, update the compiled code using {@link MagicString}.
 */
export declare function transformDefineMeta(params: Params): void;
export declare function createMetaVariableDeclaration({ init, }: {
    init: ESTreeAST.ObjectExpression;
}): ESTreeAST.VariableDeclaration;
export {};
