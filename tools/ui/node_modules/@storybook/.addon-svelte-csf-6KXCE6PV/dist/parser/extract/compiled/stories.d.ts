import type { CompiledASTNodes } from './nodes.js';
import type { ESTreeAST } from '../../ast.js';
interface Params {
    nodes: CompiledASTNodes;
    filename?: string;
}
type Result = (ESTreeAST.CallExpression | ESTreeAST.ExpressionStatement)[];
export declare function extractStoriesNodesFromExportDefaultFn(params: Params): Promise<Result>;
export {};
