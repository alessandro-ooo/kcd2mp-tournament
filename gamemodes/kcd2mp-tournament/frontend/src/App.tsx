import { Route, Switch } from "wouter";
import { lazy } from "react";

const DuelSettingsPage = lazy(() => import("./wouter/duel-settings-page"));

const App = () => {
  return (
    <Switch>
      <Route path="/duel-settings-page" component={DuelSettingsPage} />
    </Switch>
  );
};

export default App;
