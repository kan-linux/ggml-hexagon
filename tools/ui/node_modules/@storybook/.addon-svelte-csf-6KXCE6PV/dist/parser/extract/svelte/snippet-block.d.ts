import type { SvelteAST } from '../../ast.js';
import type { SvelteASTNodes } from './nodes.js';
/**
 * For example:
 *
 * ```svelte
 * {#snippet myTemplate()}
 *   <SomeComponent color="red" />
 * {/snippet}
 * <Story template={myTemplate} />
 * ```
 *
 * This function attempts to extract the AST node of the snippet block from the root fragment of `*.svelte` file,
 * which was referenced by the attribute `template`. Following example above - it would be snippet `myTemplate`.
 */
export declare function findStoryAttributeTemplateSnippetBlock(options: {
    component: SvelteAST.Component;
    nodes: SvelteASTNodes;
    filename?: string;
}): SvelteAST.SnippetBlock | undefined;
/**
 * Find and extract the AST node of snippet block referenced with `render` in `defineMeta`.
 *
 * For example:
 *
 * ```svelte
 * <script>
 *   import { defineMeta } from "@storybook/addon-svelte-csf";
 *
 *   const { Story } = defineMeta({
 *     render: myCustomTemplate,
 *   });
 * </script>
 *
 * {#snippet myCustomTemplate()}
 *   ...
 * {/snippet}
 *
 * <Story />
 * ```
 */
export declare function findMetaRenderSnippetBlock(options: {
    nodes: SvelteASTNodes;
    filename?: string;
}): SvelteAST.SnippetBlock | undefined;
