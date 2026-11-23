/** Shared API error payloads (stable `error` codes for clients). */

export const conversationNotFound = {
  error: 'not_found' as const,
  message:
    'Conversation not found. Local chat history is cleared when the API restarts — start a new chat.',
};
