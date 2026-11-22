import type { SvelteAST } from '../../../parser/ast.js';
interface Params {
    component: SvelteAST.Component;
}
/**
 *
 * Codemod to transform AST node of `<Template>` component to `SnippetBlock`
 *
 * Two cases to cover:
 *
 * @example 1. without provided `id` prop _(attribute)_
 * ```diff
 * - <Template let:args let:context>
 * + {#snippet template(args, context)}
 *     <!-- fragment -> body -->
 * + {/snippet}
 * - </Template>
 * ```
 *
 * @example 2. with provided `id` prop _(attribute)_
 * ```diff
 * - <Template id="coolTemplate" let:args let:context>
 * + {#snippet coolTemplate(args, context)}
 *     <!-- fragment -> body -->
 * + {/snippet}
 * - </Template>
 * ```
 */
export declare function transformTemplateToSnippet(params: Params): SvelteAST.SnippetBlock;
export {};
