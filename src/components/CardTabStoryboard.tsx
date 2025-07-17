import CardTab from "./CardTab";

export default function CardTabStoryboard() {
  const mockBalance = {
    dzd: 25000,
    eur: 150,
    usd: 180,
    gbp: 120,
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-900 via-blue-900 to-indigo-900">
      <CardTab isActivated={true} balance={mockBalance} />
    </div>
  );
}
