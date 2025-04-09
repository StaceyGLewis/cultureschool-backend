// App.jsx
import React, { useEffect, useState } from 'react';
import PinCard from './PinCard';
import ProfileHeader from './ProfileHeader.js';
import './App.css';

const backendUrl = process.env.REACT_APP_BACKEND_URL;
const testEmail = process.env.REACT_APP_TEST_EMAIL;

export default function App() {
  const [pins, setPins] = useState([]);
  const [error, setError] = useState(null);

  useEffect(() => {
    fetch(`${backendUrl}/api/get-pins?email=${testEmail}`)
      .then(res => {
        if (!res.ok) throw new Error(`HTTP error! status: ${res.status}`);
        return res.json();
      })
      .then(json => {
        console.log("📦 Pin response:", json);
        if (json.success && Array.isArray(json.data)) setPins(json.data);
        else throw new Error('Failed to load pins');
      })
      .catch(err => {
        console.error("❌ Error loading pins:", err);
        setError(err.message);
      });
  }, []);

  return (
    <div className="gallery-container">
      <ProfileHeader 
        name="Stacey Grant"
        bio="Collecting moments, memories, and marvels."
        profile_pic="https://i.imgur.com/l60Hf.png"
      />

      {error && <p className="error">❌ {error}</p>}

      <div className="gallery-grid">
        {pins.length ? (
          pins.map(pin => (
            <PinCard key={pin.id} {...pin} />
          ))
        ) : (
          <p>📭 No pins yet!</p>
        )}
      </div>
    </div>
  );
}
