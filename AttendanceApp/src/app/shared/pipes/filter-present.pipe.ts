import { Pipe, PipeTransform } from '@angular/core';

@Pipe({
    name: 'filterPresent',
    standalone: true
})
export class FilterPresentPipe implements PipeTransform {
    transform(items: any[]): any[] {
        if (!items) return [];
        return items.filter(item => item.status === 'present');
    }
}
