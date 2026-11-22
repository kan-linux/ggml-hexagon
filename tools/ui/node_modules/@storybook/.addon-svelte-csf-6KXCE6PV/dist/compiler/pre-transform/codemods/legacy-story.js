import { createASTArrayExpression, createASTAttribute, createASTExpressionTag, createASTObjectExpression, createASTProperty, } from '../../../parser/ast.js';
import { InvalidTemplateAttribute } from '../../../utils/error/legacy-api/index.js';
import { hashTemplateName } from '../../../utils/identifier-utils.js';
import { SVELTE_CSF_V4_TAG } from '../../../constants.js';
export function transformLegacyStory(params) {
    const { component, filename, state } = params;
    let { attributes, fragment, ...rest } = component;
    let newAttributes = [];
    let autodocs;
    let source;
    let parameters;
    let tags;
    let letDirectiveArgs;
    let letDirectiveContext;
    let hasTemplateAttribute = false;
    for (let attribute of attributes) {
        if (attribute.type === 'LetDirective' && attribute.name === 'args') {
            letDirectiveArgs = attribute;
            continue;
        }
        if (attribute.type === 'LetDirective' && attribute.name === 'context') {
            letDirectiveContext = attribute;
            continue;
        }
        if (attribute.type === 'Attribute' && attribute.name === 'autodocs') {
            autodocs = attribute;
            continue;
        }
        if (attribute.type === 'Attribute' && attribute.name === 'source') {
            source = attribute;
            continue;
        }
        if (attribute.type === 'Attribute' && attribute.name === 'parameters') {
            parameters = attribute;
            continue;
        }
        if (attribute.type === 'Attribute' && attribute.name === 'tags') {
            tags = attribute;
            continue;
        }
        if (attribute.type === 'Attribute' && attribute.name === 'template') {
            attribute = templateToChildren(attribute, filename);
            hasTemplateAttribute = true;
        }
        newAttributes.push(attribute);
    }
    // NOTE: is self-closing
    // AND has no template attribute
    // AND there is an existing unidentified <Template> components in the stories file
    if (fragment.nodes.length === 0 && !hasTemplateAttribute && state.unidentifiedTemplateComponent) {
        newAttributes.push(createASTAttribute('template', createASTExpressionTag({
            type: 'Identifier',
            name: 'sb_default_template',
        })));
    }
    if (!tags) {
        tags = createASTAttribute('tags', createASTExpressionTag(createASTArrayExpression()));
    }
    if (autodocs) {
        transformAutodocs({
            autodocs,
            tags,
            newAttributes,
        });
    }
    if (source) {
        transformSource({
            source,
            parameters,
            newAttributes,
        });
    }
    if (letDirectiveArgs || letDirectiveContext) {
        fragment = transformFragment({
            letDirectiveArgs,
            letDirectiveContext,
            fragment,
        });
    }
    if (parameters) {
        newAttributes.push(parameters);
    }
    // Always add SVELTE_CSF_V4_TAG tag to all legacy stories
    if (typeof tags.value === 'object' &&
        !Array.isArray(tags.value) &&
        tags.value.type === 'ExpressionTag' &&
        tags.value.expression.type === 'ArrayExpression' &&
        !tags.value.expression.elements.some((el) => el && el.type === 'Literal' && el.value === SVELTE_CSF_V4_TAG)) {
        tags.value.expression.elements.push({
            type: 'Literal',
            value: SVELTE_CSF_V4_TAG,
        });
    }
    newAttributes.push(tags);
    return {
        ...rest,
        attributes: newAttributes,
        fragment,
    };
}
function transformAutodocs(params) {
    let { autodocs, tags, newAttributes } = params;
    if (!autodocs) {
        return;
    }
    if (!tags) {
        tags = createASTAttribute('tags', createASTExpressionTag(createASTArrayExpression()));
    }
    const autodocsLiteral = {
        type: 'Literal',
        value: 'autodocs',
    };
    tags.value.expression.elements.push(autodocsLiteral);
    newAttributes.push(tags);
}
function transformSource(params) {
    let { source, parameters, newAttributes } = params;
    if (!source)
        return;
    const value = getSourceValue(source);
    if (!value)
        return;
    const codeLiteralValue = {
        type: 'Literal',
        value,
    };
    if (!parameters) {
        parameters = createASTAttribute('parameters', createASTExpressionTag(createASTObjectExpression()));
    }
    let docsProperty = parameters.value.expression.properties.find((property) => property.type === 'Property' && property.key.name === 'docs');
    if (!docsProperty) {
        docsProperty = createASTProperty('docs', createASTObjectExpression());
    }
    let sourceProperty = docsProperty.value.properties.find((property) => property.type === 'Property' && property.key.name === 'source');
    if (!sourceProperty) {
        sourceProperty = createASTProperty('source', createASTObjectExpression());
    }
    let codeProperty = sourceProperty.value.properties.find((property) => property.type === 'Property' && property.key.name === 'code');
    if (!codeProperty) {
        codeProperty = createASTProperty('code', codeLiteralValue);
        sourceProperty.value.properties.push(codeProperty);
        docsProperty.value.properties.push(sourceProperty);
        parameters.value.expression.properties.push(docsProperty);
    }
    newAttributes.push(parameters);
}
function getSourceValue(attribute) {
    const { value } = attribute;
    if (value === true) {
        return;
    }
    if (!Array.isArray(value)) {
        if (value.expression.type === 'Literal' && typeof value.expression.value === 'string') {
            return value.expression.value;
        }
        if (value.expression.type === 'TemplateLiteral') {
            return value.expression.quasis.map((q) => q.value.cooked).join('');
        }
    }
    if (value[0].type === 'Text') {
        return value[0].raw;
    }
}
function templateToChildren(attribute, filename) {
    const { name, value, ...rest } = attribute;
    if (value === true) {
        throw new InvalidTemplateAttribute({ attribute, filename });
    }
    return {
        ...rest,
        name: 'template',
        value: [
            createASTExpressionTag({
                type: 'Identifier',
                name: hashTemplateName(value[0].type === 'Text'
                    ? value[0].data
                    : value[0].expression.value),
            }),
        ],
    };
}
function transformFragment(params) {
    let { letDirectiveArgs, letDirectiveContext, fragment } = params;
    let parameters = [
        {
            type: 'Identifier',
            name: letDirectiveArgs ? 'args' : '_args',
        },
    ];
    if (letDirectiveContext) {
        parameters.push({
            type: 'Identifier',
            name: 'context',
        });
    }
    const snippetBlock = {
        type: 'SnippetBlock',
        body: fragment,
        expression: {
            type: 'Identifier',
            name: 'template',
        },
        parameters,
    };
    return {
        ...fragment,
        nodes: [snippetBlock],
    };
}
