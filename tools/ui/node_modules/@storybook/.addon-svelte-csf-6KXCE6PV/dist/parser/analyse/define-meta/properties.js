import { ArrayElementNotStringError, NoArrayExpressionError, NoStringLiteralError, } from '../../../utils/error/parser/analyse/define-meta.js';
export function getPropertyStringValue(options) {
    const { node, filename } = options;
    if (node.value.type !== 'Literal') {
        throw new NoStringLiteralError({ filename, property: node });
    }
    const { value } = node.value;
    if (typeof value !== 'string') {
        throw new NoStringLiteralError({ filename, property: node });
    }
    return value;
}
export function getPropertyArrayOfStringsValue(options) {
    const { node, filename } = options;
    if (node.value.type !== 'ArrayExpression') {
        throw new NoArrayExpressionError({ filename, property: node });
    }
    const array = [];
    for (const element of node.value.elements) {
        if (!element || element.type !== 'Literal' || typeof element.value !== 'string') {
            throw new ArrayElementNotStringError({
                filename,
                property: node,
                element,
            });
        }
        array.push(element.value);
    }
    return array;
}
