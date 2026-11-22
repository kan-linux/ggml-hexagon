import MagicString from 'magic-string';
import type { CompiledASTNodes } from '../../parser/extract/compiled/nodes.js';
import type { SvelteASTNodes } from '../../parser/extract/svelte/nodes.js';
interface Params {
    code: MagicString;
    nodes: {
        compiled: CompiledASTNodes;
        svelte: SvelteASTNodes;
    };
    filename?: string;
}
export declare function createAppendix(params: Params): Promise<void>;
export {};
