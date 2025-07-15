export async function dropboxLoader() {
  const url = 'https://dl.dropboxusercontent.com/scl/fi/o2je5n0ib8v4zsjeq12ix/photo-database.json?rlkey=gm6ofx2gq2g8u8te976gwqs7d&dl=1';
  const res = await fetch(url);
  if (!res.ok) throw new Error('HTTP ' + res.status);
  return await res.json();
}