import { type ESTreeAST } from '../../../parser/ast.js';
import type { createVariableFromRuntimeStoriesCall } from './create-variable-from-runtime-stories-call.js';
interface RuntimeStoryVariableDeclarationParams {
    exportName: string;
    filename?: string;
    nodes: {
        variable: ReturnType<typeof createVariableFromRuntimeStoriesCall>;
        tags?: ESTreeAST.ArrayExpression;
    };
}
export declare function createRuntimeStoryVariableDeclaration(params: RuntimeStoryVariableDeclarationParams): ESTreeAST.VariableDeclaration;
export {};
