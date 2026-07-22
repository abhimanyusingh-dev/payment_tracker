import { useEffect, useMemo, useState } from 'react';
import { isSupabaseConfigured, supabase } from './supabase';

const formatMoney = (value, currency = '₹') => {
  const amount = Number(value || 0);
  const currencyCode = currency === '₹' ? 'INR' : currency || 'INR';

  return new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: currencyCode,
    maximumFractionDigits: amount % 1 === 0 ? 0 : 2,
  }).format(amount);
};

const formatTimestamp = (value) => {
  if (!value) {
    return 'Unknown time';
  }

  const date = new Date(value);
  return new Intl.DateTimeFormat('en-IN', {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(date);
};

const formatDayLabel = (value) => {
  if (!value) {
    return 'Unknown day';
  }

  const date = new Date(`${value}T00:00:00`);
  return new Intl.DateTimeFormat('en-IN', {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  }).format(date);
};

const toLocalDateKey = (value) => {
  if (!value) {
    return '';
  }

  const date = new Date(value);
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
};

const normalizePayment = (row) => ({
  id: row.id,
  transactionKey: row.transaction_key || '',
  sourceId: row.source_id,
  packageName: row.package_name,
  appName: row.app_name,
  amount: Number(row.amount || 0),
  received: Boolean(row.received),
  payeeName: row.payee_name || '',
  timestamp: row.timestamp,
  status: row.status || 'unknown',
  transactionId: row.transaction_id || '',
  referenceId: row.reference_id || '',
  upiId: row.upi_id || '',
  currency: row.currency || '₹',
  title: row.raw_title || '',
  description: row.raw_body || row.raw_text || '',
  rawTitle: row.raw_title || '',
  rawBody: row.raw_body || '',
  rawText: row.raw_text || '',
  note: row.note || '',
  maskedAccount: row.masked_account || '',
});

function StatCard({ label, value, hint, tone = 'default' }) {
  return (
    <div className={`stat-card stat-card--${tone}`}>
      <span>{label}</span>
      <strong>{value}</strong>
      <p>{hint}</p>
    </div>
  );
}

function PaymentCard({ payment }) {
  return (
    <article className="payment-card received">
      <div className="payment-card__top">
        <div>
          <div className="payment-card__app">{payment.appName}</div>
          <div className="payment-card__meta">Credited · {payment.status}</div>
        </div>
        <div className="payment-card__amount">
          {formatMoney(payment.amount, payment.currency)}
        </div>
      </div>

      <div className="payment-card__grid">
        <div>
          <span>Title</span>
          <strong>{payment.title || 'Not captured'}</strong>
        </div>
        <div>
          <span>Description</span>
          <strong>{payment.description || 'Not captured'}</strong>
        </div>
        <div>
          <span>Payee</span>
          <strong>{payment.payeeName || 'Not captured'}</strong>
        </div>
        <div>
          <span>Timestamp</span>
          <strong>{formatTimestamp(payment.timestamp)}</strong>
        </div>
{/*         <div> */}
{/*           <span>Transaction</span> */}
{/*           <strong>{payment.transactionId || payment.referenceId || 'Not captured'}</strong> */}
{/*         </div> */}
{/*         <div> */}
{/*           <span>Transaction key</span> */}
{/*           <strong>{payment.transactionKey || 'Not captured'}</strong> */}
{/*         </div> */}
{/*         <div> */}
{/*           <span>Source</span> */}
{/*           <strong>{payment.packageName}</strong> */}
{/*         </div> */}
      </div>

      {(payment.note || payment.maskedAccount) && (
        <div className="payment-card__footer">
          {payment.note && <p>{payment.note}</p>}
          {payment.maskedAccount && <p>{payment.maskedAccount}</p>}
        </div>
      )}
    </article>
  );
}

export default function App() {
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState('');
  const [search, setSearch] = useState('');
  const [appFilter, setAppFilter] = useState('all');
  const [dateFilter, setDateFilter] = useState('');

  const loadPayments = async () => {
    if (!isSupabaseConfigured) {
      setError('Missing VITE_SUPABASE_URL or VITE_SUPABASE_ANON_KEY.');
      setLoading(false);
      setRefreshing(false);
      return;
    }

    setError('');
    setRefreshing(true);

    const { data, error: queryError } = await supabase
      .from('payment_events')
      .select('*')
      .eq('received', true)
      .order('timestamp', { ascending: false })
      .limit(500);

    if (queryError) {
      setError(queryError.message);
      setLoading(false);
      setRefreshing(false);
      return;
    }

    setRows((data || []).map(normalizePayment));
    setLoading(false);
    setRefreshing(false);
  };

  useEffect(() => {
    loadPayments();
  }, []);

  const appOptions = useMemo(() => {
    return Array.from(new Set(rows.map((row) => row.appName))).sort();
  }, [rows]);

  const filteredRows = useMemo(() => {
    const term = search.trim().toLowerCase();
    return rows.filter((row) => {
      if (appFilter !== 'all' && row.appName !== appFilter) {
        return false;
      }

      if (dateFilter && toLocalDateKey(row.timestamp) !== dateFilter) {
        return false;
      }

      if (!term) {
        return true;
      }

        return [
          row.appName,
          row.packageName,
          row.transactionKey,
          row.title,
          row.description,
          row.payeeName,
          row.transactionId,
          row.referenceId,
          row.upiId,
        row.note,
        row.rawBody,
      ]
        .filter(Boolean)
        .some((field) => String(field).toLowerCase().includes(term));
    });
  }, [rows, search, appFilter, dateFilter]);

  const dayGroups = useMemo(() => {
    const grouped = new Map();

    for (const row of filteredRows) {
      const key = toLocalDateKey(row.timestamp) || 'unknown';
      if (!grouped.has(key)) {
        grouped.set(key, []);
      }
      grouped.get(key).push(row);
    }

    return Array.from(grouped.entries()).map(([dateKey, groupRows]) => ({
      dateKey,
      label: dateKey === 'unknown' ? 'Unknown day' : formatDayLabel(dateKey),
      rows: groupRows,
      total: groupRows.reduce((sum, row) => sum + row.amount, 0),
      latest: groupRows[0]?.timestamp || '',
    }));
  }, [filteredRows]);

  const totals = useMemo(() => {
    return filteredRows.reduce(
      (acc, row) => {
        acc.count += 1;
        acc.credited += row.amount;
        acc.apps.add(row.appName);
        acc.latest = row.timestamp || acc.latest;
        return acc;
      },
      {
        count: 0,
        credited: 0,
        apps: new Set(),
        latest: '',
      },
    );
  }, [filteredRows]);

  return (
    <main className="shell">
      <section className="hero">
        <div>
          <p className="eyebrow">SINGH CABLE NETWORK</p>
          <h1>Payment Tracker</h1>
          <p className="hero__copy">
            A dashboard displaying payment information from PhonePe, Google Pay, Google Pay
            Business, and Paytm payments.
          </p>
          {!isSupabaseConfigured && (
            <p className="hero__copy hero__copy--alert">
              Add <code>VITE_SUPABASE_URL</code> and <code>VITE_SUPABASE_ANON_KEY</code> in{' '}
              <code>.env.local</code> to load data.
            </p>
          )}
        </div>

        <div className="hero__status">
          <span className={`status-dot ${error ? 'status-dot--error' : 'status-dot--ok'}`} />
          <div>
            <strong>{error ? 'Sync issue' : 'Connected'}</strong>
            <p>{error || 'Payment_events is live.'}</p>
          </div>
          <button type="button" onClick={loadPayments} disabled={refreshing}>
            {refreshing ? 'Refreshing...' : 'Refresh'}
          </button>
        </div>
      </section>

      <section className="toolbar">
        <label>
          <span>Search</span>
          <input
            type="search"
            placeholder="App, payee, UPI, note..."
            value={search}
            onChange={(event) => setSearch(event.target.value)}
          />
        </label>

        <label>
          <span>App</span>
          <select value={appFilter} onChange={(event) => setAppFilter(event.target.value)}>
            <option value="all">All apps</option>
            {appOptions.map((app) => (
              <option key={app} value={app}>
                {app}
              </option>
            ))}
          </select>
        </label>

        <label>
          <span>Date</span>
          <input
            type="date"
            value={dateFilter}
            onChange={(event) => setDateFilter(event.target.value)}
          />
        </label>

      </section>

      <section className="stats">
        <StatCard
          label="Visible payments"
          value={totals.count}
          hint="Rows matching the current filters."
          tone="teal"
        />
        <StatCard
          label="Credited total"
          value={formatMoney(totals.credited)}
          hint="Incoming money from payment apps."
          tone="green"
        />
        <StatCard
          label="Apps in view"
          value={totals.apps.size}
          hint={`${totals.apps.size} payment app${totals.apps.size === 1 ? '' : 's'} shown.`}
          tone="blue"
        />
        <StatCard
          label="Days in view"
          value={dayGroups.length}
          hint="Grouped by calendar day."
          tone="teal"
        />
      </section>

      <section className="content">
        <div className="content__header">
          <div>
            <h2>Transactions</h2>
            <p>
              {dateFilter ? formatDayLabel(dateFilter) : 'All days'} · Latest sync:{' '}
              {totals.latest ? formatTimestamp(totals.latest) : 'No records yet'}
            </p>
          </div>
          <div className="content__count">
            {filteredRows.length} rows across {dayGroups.length} day
            {dayGroups.length === 1 ? '' : 's'}
          </div>
        </div>

        {loading ? (
          <div className="empty-state">Loading payment rows from Supabase...</div>
        ) : error ? (
          <div className="empty-state empty-state--error">{error}</div>
        ) : filteredRows.length === 0 ? (
          <div className="empty-state">
            No payments match the current filters. Try a broader search or refresh the data.
          </div>
        ) : (
          <div className="day-groups">
            {dayGroups.map((group) => (
              <section key={group.dateKey} className="day-group">
                <div className="day-group__header">
                  <div>
                    <h3>{group.label}</h3>
                    <p>{group.rows.length} credited payment{group.rows.length === 1 ? '' : 's'}</p>
                  </div>
                  <strong>{formatMoney(group.total)}</strong>
                </div>
                <div className="payments">
                  {group.rows.map((payment) => (
                    <PaymentCard key={payment.id} payment={payment} />
                  ))}
                </div>
              </section>
            ))}
          </div>
        )}
      </section>
    </main>
  );
}
