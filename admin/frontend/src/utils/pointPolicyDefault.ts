export const createDefaultPointPolicyDoc = () => ({
  type: 'doc',
  content: [
    {
      type: 'heading',
      attrs: { level: 2 },
      content: [{ type: 'text', text: 'Conversion Rate' }],
    },
    {
      type: 'paragraph',
      content: [{ type: 'text', text: '1 Point = NT$1' }],
    },
    {
      type: 'heading',
      attrs: { level: 2 },
      content: [{ type: 'text', text: 'Purchasing Points & Reward Rules' }],
    },
    {
      type: 'table',
      content: [
        {
          type: 'tableRow',
          content: [
            {
              type: 'tableHeader',
              attrs: { colspan: 1, rowspan: 1, colwidth: null },
              content: [{ type: 'paragraph', content: [{ type: 'text', text: 'Purchase Amount (NT$)' }] }],
            },
            {
              type: 'tableHeader',
              attrs: { colspan: 1, rowspan: 1, colwidth: null },
              content: [{ type: 'paragraph', content: [{ type: 'text', text: 'Bonus Offer' }] }],
            },
          ],
        },
        {
          type: 'tableRow',
          content: [
            {
              type: 'tableCell',
              attrs: { colspan: 1, rowspan: 1, colwidth: null },
              content: [{ type: 'paragraph', content: [{ type: 'text', text: 'Below 600' }] }],
            },
            {
              type: 'tableCell',
              attrs: { colspan: 1, rowspan: 1, colwidth: null },
              content: [{ type: 'paragraph', content: [{ type: 'text', text: 'No coupon issued' }] }],
            },
          ],
        },
        {
          type: 'tableRow',
          content: [
            {
              type: 'tableCell',
              attrs: { colspan: 1, rowspan: 1, colwidth: null },
              content: [{ type: 'paragraph', content: [{ type: 'text', text: '600–999' }] }],
            },
            {
              type: 'tableCell',
              attrs: { colspan: 1, rowspan: 1, colwidth: null },
              content: [
                {
                  type: 'paragraph',
                  content: [
                    {
                      type: 'text',
                      text: '30-point discount coupon applicable to task payments (e.g., for a 600-point task, only 570 points are required after applying the coupon).',
                    },
                  ],
                },
              ],
            },
          ],
        },
        {
          type: 'tableRow',
          content: [
            {
              type: 'tableCell',
              attrs: { colspan: 1, rowspan: 1, colwidth: null },
              content: [{ type: 'paragraph', content: [{ type: 'text', text: '1,000–1499' }] }],
            },
            {
              type: 'tableCell',
              attrs: { colspan: 1, rowspan: 1, colwidth: null },
              content: [
                {
                  type: 'paragraph',
                  content: [
                    {
                      type: 'text',
                      text: 'Get an additional 100 points credited to your balance (e.g., pay 1,500, receive 1,600 points).',
                    },
                  ],
                },
              ],
            },
          ],
        },
        {
          type: 'tableRow',
          content: [
            {
              type: 'tableCell',
              attrs: { colspan: 1, rowspan: 1, colwidth: null },
              content: [{ type: 'paragraph', content: [{ type: 'text', text: '2,000 and above' }] }],
            },
            {
              type: 'tableCell',
              attrs: { colspan: 1, rowspan: 1, colwidth: null },
              content: [
                {
                  type: 'paragraph',
                  content: [
                    {
                      type: 'text',
                      text: 'Get an additional 150 points credited (e.g., pay 2000, recive 2,150 points).',
                    },
                  ],
                },
              ],
            },
          ],
        },
      ],
    },
    {
      type: 'heading',
      attrs: { level: 2 },
      content: [{ type: 'text', text: 'Points Withdrawal Policy' }],
    },
    {
      type: 'bulletList',
      content: [
        {
          type: 'listItem',
          content: [
            {
              type: 'paragraph',
              content: [
                { type: 'text', text: 'Points earned from completed tasks will be disbursed to the task taker on the ' },
                { type: 'text', text: '10th of the following month', marks: [{ type: 'bold' }] },
                { type: 'text', text: '.' },
              ],
            },
          ],
        },
        {
          type: 'listItem',
          content: [
            {
              type: 'paragraph',
              content: [{ type: 'text', text: 'Any task under dispute is excluded from scheduled disbursement.' }],
            },
          ],
        },
        {
          type: 'listItem',
          content: [
            {
              type: 'paragraph',
              content: [
                { type: 'text', text: 'Once a dispute is resolved, the corresponding points will be disbursed ' },
                { type: 'text', text: 'within 7 days', marks: [{ type: 'bold' }] },
                { type: 'text', text: ' of resolution.' },
              ],
            },
          ],
        },
      ],
    },
  ],
});

export type PointPolicyDoc = ReturnType<typeof createDefaultPointPolicyDoc>;
