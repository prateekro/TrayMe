use tauri::State;
use crate::state::AppState;
use aes_gcm::{
    aead::{Aead, KeyInit, OsRng},
    Aes256Gcm, Nonce,
};
use base64::{engine::general_purpose, Engine as _};
use rand::RngCore;

/// Encrypt data using AES-256-GCM
#[tauri::command]
pub async fn encrypt_data(
    data: String,
    key: String,
    _state: State<'_, AppState>,
) -> Result<String, String> {
    tracing::info!("Encrypting data ({} bytes)", data.len());
    
    // Decode the key from base64
    let key_bytes = general_purpose::STANDARD
        .decode(key.as_bytes())
        .map_err(|e| format!("Failed to decode key: {}", e))?;
    
    if key_bytes.len() != 32 {
        return Err("Key must be 32 bytes (256 bits)".to_string());
    }
    
    let cipher = Aes256Gcm::new_from_slice(&key_bytes)
        .map_err(|e| format!("Failed to create cipher: {}", e))?;
    
    // Generate a random nonce
    let mut nonce_bytes = [0u8; 12];
    OsRng.fill_bytes(&mut nonce_bytes);
    let nonce = Nonce::from_slice(&nonce_bytes);
    
    // Encrypt the data
    let ciphertext = cipher
        .encrypt(nonce, data.as_bytes())
        .map_err(|e| format!("Encryption failed: {}", e))?;
    
    // Combine nonce and ciphertext
    let mut result = nonce_bytes.to_vec();
    result.extend_from_slice(&ciphertext);
    
    // Encode to base64
    Ok(general_purpose::STANDARD.encode(result))
}

/// Decrypt data using AES-256-GCM
#[tauri::command]
pub async fn decrypt_data(
    encrypted_data: String,
    key: String,
    _state: State<'_, AppState>,
) -> Result<String, String> {
    tracing::info!("Decrypting data");
    
    // Decode the encrypted data from base64
    let encrypted_bytes = general_purpose::STANDARD
        .decode(encrypted_data.as_bytes())
        .map_err(|e| format!("Failed to decode encrypted data: {}", e))?;
    
    if encrypted_bytes.len() < 12 {
        return Err("Invalid encrypted data".to_string());
    }
    
    // Decode the key from base64
    let key_bytes = general_purpose::STANDARD
        .decode(key.as_bytes())
        .map_err(|e| format!("Failed to decode key: {}", e))?;
    
    if key_bytes.len() != 32 {
        return Err("Key must be 32 bytes (256 bits)".to_string());
    }
    
    let cipher = Aes256Gcm::new_from_slice(&key_bytes)
        .map_err(|e| format!("Failed to create cipher: {}", e))?;
    
    // Extract nonce and ciphertext
    let (nonce_bytes, ciphertext) = encrypted_bytes.split_at(12);
    let nonce = Nonce::from_slice(nonce_bytes);
    
    // Decrypt the data
    let plaintext = cipher
        .decrypt(nonce, ciphertext)
        .map_err(|e| format!("Decryption failed: {}", e))?;
    
    String::from_utf8(plaintext)
        .map_err(|e| format!("Failed to convert decrypted data to string: {}", e))
}
