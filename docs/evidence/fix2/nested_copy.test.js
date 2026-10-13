// Negative Control Proof: Intentionally invalid or unnested describe block
describe('Parent Describe', () => {
  it('should be valid', () => {
    expect(true).toBe(true);
  });
});
