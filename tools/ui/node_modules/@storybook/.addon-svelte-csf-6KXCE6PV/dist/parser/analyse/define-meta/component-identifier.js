import { extractDefineMetaPropertiesNodes } from '../../extract/svelte/define-meta.js';
import { InvalidComponentValueError } from '../../../utils/error/parser/analyse/define-meta.js';
export function getDefineMetaComponentValue(params) {
    const { nodes, filename } = params;
    const { component } = extractDefineMetaPropertiesNodes({
        nodes,
        properties: ['component'],
    });
    if (!component) {
        return;
    }
    const { value } = component;
    if (value.type !== 'Identifier') {
        throw new InvalidComponentValueError({
            filename,
            componentProperty: component,
        });
    }
    return value;
}
