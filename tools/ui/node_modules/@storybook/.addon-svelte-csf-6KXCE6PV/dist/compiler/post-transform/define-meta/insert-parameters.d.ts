import type { SvelteASTNodes } from '../../../parser/extract/svelte/nodes.js';
import type { CompiledASTNodes } from '../../../parser/extract/compiled/nodes.js';
interface Params {
    nodes: {
        compiled: CompiledASTNodes;
        svelte: SvelteASTNodes;
    };
    filename?: string;
}
/**
 * This function inserts parameters to `defineMeta()`.
 * Attempt to insert JSDoc comment above the `defineMeta()` call.
 *
 * Before:
 *
 * ```js
 * // Some description about the component
 * const { Story } = defineMeta({});
 * ```
 *
 * After:
 * ```js
 * // Some description about the component
 * const { Story } = defineMeta({
 *   parameters: {
 *     docs: {
 *       description: { component: "Some description about the component" },
 *     },
 *   },
 * });
 * ```
 */
export declare function insertDefineMetaParameters(params: Params): void;
export {};
