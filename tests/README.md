Run the receipt/build regression checks from the repository root:

```sh
python -m unittest discover -s tests -p 'test_*.py'
```

Run the browser checks (test data stays in an isolated browser session):

```sh
cd tests
npm install
npx playwright install chromium --only-shell
npm test
```

The browser suite checks startup, outlet/customer creation, transport charges,
static QRIS payment/upload/reload, DP/deposit, quiet detail updates, material
usage/reversal and courier navigation. Native camera, printer, and QRIS banking
settlement still need verification on a physical phone.
