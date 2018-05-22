import { stringify } from 'query-string';

import { FilterDefinition } from '../../types/filters';
import * as filterComputer from './computeNewFilterValue';
import { updateFilter } from './updateFilter';

describe('utils/filters/updateFilter', () => {
  let dispatch: jasmine.Spy;

  beforeEach(() => {
    dispatch = jasmine.createSpy('dispatch');
    spyOn(filterComputer, 'computeNewFilterValue').and.returnValue(
      'some filter value',
    );
  });

  it('dispatches relevant actions with the updated params', () => {
    updateFilter(
      dispatch,
      'add',
      { isDrilldown: true, machineName: 'status' } as FilterDefinition,
      'some filter value',
      { limit: 13, offset: 3, organizations: [42, 84] },
    );

    expect(dispatch).toHaveBeenCalledWith({
      params: {
        limit: 13,
        offset: 3,
        organizations: [42, 84],
        status: 'some filter value',
      },
      resourceName: 'courses',
      type: 'RESOURCE_LIST_GET',
    });
    expect(dispatch).toHaveBeenCalledWith({
      state: null,
      title: '',
      type: 'HISTORY_PUSH_STATE',
      url: `?${stringify({
        limit: 13,
        offset: 3,
        organizations: [42, 84],
        status: 'some filter value',
      })}`,
    });
  });
});