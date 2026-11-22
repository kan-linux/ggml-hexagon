import type { ESTreeAST } from '../../ast.js';
import type { SvelteASTNodes } from '../../extract/svelte/nodes.js';
interface Params {
    nodes: SvelteASTNodes;
    filename?: string;
}
export declare function getDefineMetaRenderValue(params: Params): ESTreeAST.Identifier | undefined;
export {};
