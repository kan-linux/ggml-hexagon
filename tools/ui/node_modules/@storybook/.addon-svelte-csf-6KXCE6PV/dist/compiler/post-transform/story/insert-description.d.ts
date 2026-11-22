import type { extractStoriesNodesFromExportDefaultFn } from '../../../parser/extract/compiled/stories.js';
import type { SvelteASTNodes } from '../../../parser/extract/svelte/nodes.js';
interface Params {
    nodes: {
        svelte: SvelteASTNodes['storyComponents'][number];
        compiled: Awaited<ReturnType<typeof extractStoriesNodesFromExportDefaultFn>>[number];
    };
    filename?: string;
}
/**
 * Attempt to insert HTML comment above the `<Story />` component as a description **into the compiled code**.
 * If the user did explicitly set `parameters.docs.description.story` and the HTML comment exists, then it will log a warning.
 */
export declare function insertStoryHTMLCommentAsDescription(params: Params): void;
export {};
