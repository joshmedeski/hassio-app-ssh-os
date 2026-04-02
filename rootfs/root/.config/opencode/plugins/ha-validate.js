const HA_CONFIG_DIR = "/homeassistant";

export const HAValidatePlugin = async ({ $, directory }) => {
  const editedHAFiles = new Set();

  return {
    "file.edited": async (input) => {
      const filePath = input?.path || input?.file || "";
      if (filePath.startsWith(HA_CONFIG_DIR)) {
        editedHAFiles.add(filePath);
      }
    },

    "session.idle": async () => {
      if (editedHAFiles.size === 0) return;

      const files = Array.from(editedHAFiles);
      editedHAFiles.clear();

      try {
        const check = await $`ha core check --raw-json`.json();

        if (check.result === "ok") {
          return {
            type: "prompt",
            title: "Home Assistant Config Valid",
            message: [
              `Configuration check passed.`,
              `Changed files: ${files.map((f) => f.replace(HA_CONFIG_DIR + "/", "")).join(", ")}`,
              ``,
              `Would you like to restart Home Assistant to apply these changes?`,
            ].join("\n"),
            actions: [
              { label: "Restart", value: "restart" },
              { label: "Skip", value: "skip" },
            ],
            callback: async (response) => {
              if (response === "restart") {
                await $`ha core restart`;
                return {
                  type: "toast",
                  message: "Home Assistant is restarting...",
                  level: "info",
                };
              }
            },
          };
        } else {
          const errorMsg = check.data?.message || "Unknown validation error";
          return {
            type: "toast",
            message: `Config validation failed: ${errorMsg}`,
            level: "error",
          };
        }
      } catch (err) {
        return {
          type: "toast",
          message: `Could not validate config: ${err.message}`,
          level: "warning",
        };
      }
    },
  };
};
