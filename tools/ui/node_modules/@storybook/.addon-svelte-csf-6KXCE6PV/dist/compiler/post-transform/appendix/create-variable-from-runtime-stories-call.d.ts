import { type ESTreeAST } from '../../../parser/ast.js';
interface Params {
    storiesFunctionDeclaration: ESTreeAST.FunctionDeclaration;
    filename?: string;
}
export declare function createVariableFromRuntimeStoriesCall(params: Params): ESTreeAST.VariableDeclaration;
export {};
