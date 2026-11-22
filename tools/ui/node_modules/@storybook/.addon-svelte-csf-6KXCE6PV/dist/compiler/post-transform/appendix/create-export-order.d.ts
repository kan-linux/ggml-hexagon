import type { getStoriesIdentifiers } from '../../../parser/analyse/story/attributes/identifiers.js';
import { type ESTreeAST } from '../../../parser/ast.js';
interface ExportOrderVariableDeclarationParams {
    storiesIdentifiers: ReturnType<typeof getStoriesIdentifiers>;
    filename?: string;
}
export declare function createExportOrderVariableDeclaration(params: ExportOrderVariableDeclarationParams): ESTreeAST.ExportNamedDeclaration;
export {};
