// PinCard.js
import React from 'react';

const PinCard = ({ image_url, title, description }) => (
  <div className="card">
    <img src={image_url} alt={title || 'Pinned Image'} />
    <div className="card-content">
      <div className="card-title">{title || 'Untitled'}</div>
      <div className="card-desc">{description || ''}</div>
    </div>
    <div className="reaction-bar">
      <span title="Love this">💚</span>
      <span title="Share this">🔗</span>
    </div>
  </div>
);

export default PinCard;
