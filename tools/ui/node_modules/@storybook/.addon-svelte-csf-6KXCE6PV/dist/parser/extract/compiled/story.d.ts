import type { ESTreeAST } from '../../ast.js';
import type { extractStoriesNodesFromExportDefaultFn } from './stories.js';
interface Params {
    node: Awaited<ReturnType<typeof extractStoriesNodesFromExportDefaultFn>>[number];
    filename?: string;
}
/**
 * Get an {@link ObjectExpression} with props _(attributes)_ passed down to Svelte component in compiled code.
 *
 * - In **development** mode, extract from the {@link ExpressionStatement}.
 *   How it looks in **development** mode:
 *
 *   ```js
 *   $.validate_component(Story)(node_1, { props })
 *   ```
 *
 * - In **production** mode, extract from the {@link CallExpression}.
 *   And in **production** mode:
 *
 *   ```js
 *   Story(node_1, { props })
 *   ```
 */
export declare function getStoryPropsObjectExpression(params: Params): ESTreeAST.ObjectExpression;
export {};
