export const saveToken = (token) => {
  localStorage.setItem("amexan_token", token);
};

export const getToken = () => {
  return localStorage.getItem("amexan_token");
};

export const logout = () => {
  localStorage.removeItem("amexan_token");
};
