import type { getStoriesIdentifiers } from '../../../parser/analyse/story/attributes/identifiers.js';
import { type ESTreeAST } from '../../../parser/ast.js';
interface NamedExportStoriesParams {
    storiesIdentifiers: ReturnType<typeof getStoriesIdentifiers>;
}
export declare function createNamedExportStories(params: NamedExportStoriesParams): ESTreeAST.ExportNamedDeclaration;
export {};
