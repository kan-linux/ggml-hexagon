import { type ESTreeAST, type SvelteAST } from '../../parser/ast.js';
interface Params {
    ast: SvelteAST.Root;
    filename?: string;
}
export interface State {
    componentIdentifierName: ComponentIdentifierName;
    componentMetaHtmlComment?: SvelteAST.Comment;
    defineMetaFromExportConstMeta?: ESTreeAST.VariableDeclaration;
    defineMetaFromComponentMeta?: ESTreeAST.VariableDeclaration;
    currentScript?: 'instance' | 'module';
    pkgImportDeclaration?: ESTreeAST.ImportDeclaration;
    storiesComponentIdentifier?: ESTreeAST.Identifier;
    storiesComponentImportDeclaration?: ESTreeAST.ImportDeclaration;
    /**
     * There can be only one `<Template />` component without id aka *id-less*.
     * We store it to ensure there's no more than one - we will throw error if there's more.
     */
    unidentifiedTemplateComponent?: SvelteAST.Component;
}
export declare function codemodLegacyNodes(params: Params): Promise<SvelteAST.Root>;
interface ComponentIdentifierName {
    Meta?: string;
    Story?: string;
    Template?: string;
}
export {};
