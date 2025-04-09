import React from 'react';

const ProfileHeader = ({ name = "Unnamed", bio = "No bio yet.", profile_pic }) => {
  console.log("👤 ProfileHeader props:", { name, bio, profile_pic });

  return (
    <div className="gallery-header">
      {profile_pic ? (
        <img src={profile_pic} alt="Profile Pic" />
      ) : (
        <div style={{
          width: 80,
          height: 80,
          borderRadius: '50%',
          background: '#ccc',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          fontSize: 24,
          color: '#666',
          fontWeight: 'bold',
        }}>?</div>
      )}
      <div className="info">
        <h1>✨ {name}'s Moodboard</h1>
        <p>{bio}</p>
      </div>
    </div>
  );
};

export default ProfileHeader;
